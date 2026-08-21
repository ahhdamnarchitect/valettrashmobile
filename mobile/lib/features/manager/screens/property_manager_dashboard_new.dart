import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/billing/property_billing.dart';
import '../../../core/platform/csv_download_stub.dart'
    if (dart.library.html) '../../../core/platform/csv_download_web.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import 'pm_compliance_report_screen.dart';
import 'simple_notification_sender_screen.dart';
import '../../../core/utils/error_reporter.dart';

class PropertyManagerDashboardNewScreen extends StatefulWidget {
  const PropertyManagerDashboardNewScreen({super.key});

  @override
  State<PropertyManagerDashboardNewScreen> createState() =>
      _PropertyManagerDashboardNewScreenState();
}

class _PropertyManagerDashboardNewScreenState
    extends State<PropertyManagerDashboardNewScreen> {
  bool _loading = true;
  String? _error;
  String _email = '';

  int _tabIndex = 0;

  List<Map<String, dynamic>> _properties = [];
  // ignore: unused_field
  List<Map<String, dynamic>> _recentRuns = [];
  // ignore: unused_field
  String? _firstName;
  double _avgSatisfaction = 0;
  double _serviceCompliance = 0; // 0.0 – 1.0
  int _pendingComebackCount = 0;
  List<Map<String, dynamic>> _pendingComebacks = [];
  List<Map<String, dynamic>> _recentAnnouncements = [];

  AppColorsScheme _c = AppColorsScheme.dark;

  // ignore: unused_element
  int get _totalUnits =>
      _properties.fold(0, (s, p) => s + (p['unit_count'] as int? ?? 0));
  // ignore: unused_element
  int get _totalResidents =>
      _properties.fold(0, (s, p) => s + (p['resident_count'] as int? ?? 0));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c = context.roleColors;
  }

  @override
  void initState() {
    super.initState();
    _email =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    _loadData();
  }

  Future<int> _unitCountForProperty(String propertyId) async {
    final client = Supabase.instance.client;
    final buildings = await client
        .from('buildings')
        .select('id')
        .eq('property_id', propertyId);
    final buildingIds = (buildings as List)
        .map((b) => b['id']?.toString())
        .whereType<String>()
        .toList();
    if (buildingIds.isEmpty) return 0;

    final floors = await client
        .from('floors')
        .select('id')
        .filter('building_id', 'in', '(${buildingIds.join(',')})');
    final floorIds = (floors as List)
        .map((f) => f['id']?.toString())
        .whereType<String>()
        .toList();
    if (floorIds.isEmpty) return 0;

    final units = await client
        .from('units')
        .select('id')
        .filter('floor_id', 'in', '(${floorIds.join(',')})')
        .eq('is_active', true);
    return (units as List).length;
  }

  Future<List<String>> _unitIdsForProperty(String propertyId) async {
    final client = Supabase.instance.client;
    final buildings = await client
        .from('buildings')
        .select('id')
        .eq('property_id', propertyId);
    final buildingIds = (buildings as List)
        .map((b) => b['id']?.toString())
        .whereType<String>()
        .toList();
    if (buildingIds.isEmpty) return [];

    final floors = await client
        .from('floors')
        .select('id')
        .filter('building_id', 'in', '(${buildingIds.join(',')})');
    final floorIds = (floors as List)
        .map((f) => f['id']?.toString())
        .whereType<String>()
        .toList();
    if (floorIds.isEmpty) return [];

    final units = await client
        .from('units')
        .select('id')
        .filter('floor_id', 'in', '(${floorIds.join(',')})')
        .eq('is_active', true);
    return (units as List)
        .map((u) => u['id']?.toString())
        .whereType<String>()
        .toList();
  }

  /// Units at a property with resident + resident invite code (if any).
  Future<List<Map<String, dynamic>>> _loadPropertyUnitsOverview(
    String propertyId,
    List<Map<String, dynamic>> propInvites,
  ) async {
    final client = Supabase.instance.client;
    final unitIds = await _unitIdsForProperty(propertyId);
    if (unitIds.isEmpty) return [];

    final unitsRows = await client
        .from('units')
        .select('id, unit_number')
        .filter('id', 'in', '(${unitIds.join(',')})')
        .eq('is_active', true)
        .order('unit_number');

    final residents = await client
        .from('resident_units')
        .select('unit_id, users(first_name, last_name)')
        .eq('property_id', propertyId)
        .eq('is_active', true);

    final residentByUnit = <String, String>{};
    for (final r in residents as List) {
      final unitId = r['unit_id']?.toString();
      final user = r['users'];
      if (unitId == null || user is! Map) continue;
      final name =
          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
      if (name.isNotEmpty) residentByUnit[unitId] = name;
    }

    final inviteByUnit = <String, Map<String, dynamic>>{};
    for (final ic in propInvites) {
      final unitId = ic['unit_id']?.toString();
      if (unitId != null) inviteByUnit[unitId] = ic;
    }

    final overview = <Map<String, dynamic>>[];
    for (final u in unitsRows as List) {
      final unitId = u['id']?.toString() ?? '';
      final invite = inviteByUnit[unitId];
      final useCount = invite?['use_count'] as int? ?? 0;
      overview.add({
        'unit_id': unitId,
        'unit_number': u['unit_number']?.toString() ?? '—',
        'resident_name': residentByUnit[unitId],
        'is_occupied': residentByUnit.containsKey(unitId),
        'invite_code': invite?['code']?.toString(),
        'invite_claimed': invite?['assigned_user_id'] != null || useCount > 0,
      });
    }
    return overview;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Profile name
      try {
        final profile = await client
            .from('users')
            .select('first_name')
            .eq('id', uid)
            .maybeSingle();
        if (profile != null) _firstName = profile['first_name']?.toString();
      } catch (e) {
        ErrorReporter.logSilent('property_manager_dashboard_new._loadData', e);
      }

      final userPropsRows = await client
          .from('user_properties')
          .select(
            'property_id, properties(id, name, service_window_start, service_window_end, is_active, monthly_fee_per_door, minimum_billable_occupancy_percent, billing_total_doors, billing_occupied_doors)',
          )
          .eq('user_id', uid);

      final rows = List<Map<String, dynamic>>.from(userPropsRows as List);
      final List<Map<String, dynamic>> properties = [];
      for (final row in rows) {
        final propData = row['properties'];
        if (propData is! Map) continue;
        final propId = propData['id']?.toString() ?? '';
        final propName = propData['name']?.toString() ?? '';

        final results = await Future.wait(<Future<dynamic>>[
          client
              .from('resident_units')
              .select('id')
              .eq('property_id', propId)
              .eq('is_active', true),
          client
              .from('invite_codes')
              .select(
                  'id, code, unit_id, assigned_user_id, use_count, max_uses, units(unit_number)')
              .eq('property_id', propId)
              .order('created_at', ascending: false),
          _unitCountForProperty(propId),
          _unitIdsForProperty(propId),
        ]);

        final residentCount = (results[0] as List).length;
        final propInvites =
            List<Map<String, dynamic>>.from(results[1] as List);
        final unitCount = results[2] as int;
        final unitIds = results[3] as List<String>;
        final unitsOverview =
            await _loadPropertyUnitsOverview(propId, propInvites);
        final billingSnap = PropertyBilling.snapshot(
          property: Map<String, dynamic>.from(propData),
          countedUnits: unitCount,
          countedOccupied: residentCount,
        );
        final occupiedCount = billingSnap['occupied_doors'] as int;
        final totalForBilling = billingSnap['total_doors'] as int;
        final billableDoors = billingSnap['billable_doors'] as int;
        final occupancyPct = billingSnap['occupancy_percent'] as double;
        final estMonthlyBill = billingSnap['monthly_amount'] as double;
        final minPct = billingSnap['min_billable_percent'] as double;
        final feePerDoor = billingSnap['fee_per_door'] as double;

        int violationCount = 0;
        int comebackCount = 0;
        if (unitIds.isNotEmpty) {
          final violations = await client
              .from('violations')
              .select('id')
              .filter('unit_id', 'in', '(${unitIds.join(',')})')
              .eq('status', 'pending');
          violationCount = (violations as List).length;
        }

        final sw = propData['service_window_start'] ?? '18:00';
        final ew = propData['service_window_end'] ?? '22:00';

        properties.add({
          'id': propId,
          'name': propName,
          'service_window': '${_fmtTime(sw)} – ${_fmtTime(ew)}',
          'unit_count': totalForBilling,
          'unit_count_in_app': unitCount,
          'resident_count': residentCount,
          'violation_count': violationCount,
          'comeback_count': comebackCount,
          'invite_count': propInvites.length,
          'claimed_count': propInvites
              .where((c) =>
                  c['assigned_user_id'] != null ||
                  ((c['use_count'] as int? ?? 0) > 0))
              .length,
          'units_overview': unitsOverview,
          'occupied_count': occupiedCount,
          'billable_doors': billableDoors,
          'occupancy_pct': occupancyPct,
          'min_billable_pct': minPct,
          'fee_per_door': feePerDoor,
          'est_monthly_bill': estMonthlyBill,
        });

      }

      // Load recent runs, satisfaction, compliance for assigned properties
      List<Map<String, dynamic>> recentRuns = [];
      double avgSatisfaction = 0;
      double serviceCompliance = 0;
      int pendingComebackCount = 0;
      List<Map<String, dynamic>> pendingComebacks = [];
      List<Map<String, dynamic>> recentAnnouncements = [];
      final allPropIds = properties.map((p) => p['id'] as String).toList();
      if (allPropIds.isNotEmpty) {
        try {
          final runs = await client
              .from('nightly_runs')
              .select('id, run_date, status, completed_units, total_units, properties(name)')
              .filter('property_id', 'in', '(${allPropIds.join(',')})')
              .order('run_date', ascending: false)
              .limit(5);
          recentRuns = List<Map<String, dynamic>>.from(runs as List);

          // Compliance: % of completed runs out of total recent runs
          if (recentRuns.isNotEmpty) {
            final completed = recentRuns.where((r) => r['status'] == 'completed').length;
            serviceCompliance = completed / recentRuns.length;
          }
        } catch (e) {
          ErrorReporter.logSilent('property_manager_dashboard_new.operation', e);
        }
        try {
          final ratings = await client
              .from('satisfaction_ratings')
              .select('rating')
              .filter('property_id', 'in', '(${allPropIds.join(',')})');
          final ratingList = (ratings as List);
          if (ratingList.isNotEmpty) {
            final sum = ratingList.fold<double>(
                0, (acc, r) => acc + (r['rating'] as int? ?? 0).toDouble());
            avgSatisfaction = sum / ratingList.length;
          }
        } catch (e) {
          ErrorReporter.logSilent('property_manager_dashboard_new.operation', e);
        }

        try {
          final comebackRows = await client
              .from('missed_pickup_requests')
              .select(
                  'id, status, requested_at, is_free, pickups(property_id, units(unit_number))')
              .eq('status', 'pending')
              .order('requested_at', ascending: false);
          pendingComebacks = (comebackRows as List)
              .where((r) {
                final pickup = r['pickups'];
                if (pickup is! Map) return false;
                final pid = pickup['property_id']?.toString();
                return pid != null && allPropIds.contains(pid);
              })
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
          pendingComebackCount = pendingComebacks.length;
        } catch (e) {
          ErrorReporter.logSilent('property_manager_dashboard_new.operation', e);
        }

        // Recent announcements for PM's properties
        try {
          final announcements = await client
              .from('community_announcements')
              .select('id, title, body, created_at, property_id')
              .filter('property_id', 'in', '(${allPropIds.join(',')})')
              .order('created_at', ascending: false)
              .limit(3);
          recentAnnouncements = List<Map<String, dynamic>>.from(announcements as List);
        } catch (e) {
          ErrorReporter.logSilent('property_manager_dashboard_new.operation', e);
        }
      }

      setState(() {
        _properties = properties;
        _recentRuns = recentRuns;
        _avgSatisfaction = avgSatisfaction;
        _serviceCompliance = serviceCompliance;
        _pendingComebackCount = pendingComebackCount;
        _pendingComebacks = pendingComebacks;
        _recentAnnouncements = recentAnnouncements;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '--';
    final parts = t.toString().split(':');
    if (parts.length < 2) return t.toString();
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final ap = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $ap';
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }


  /// Anchor rect for the iOS share popover. Required on iPad -- share_plus throws
  /// `sharePositionOrigin: argument must be set` without it.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _exportUnitCodesCsv() async {
    final buf = StringBuffer();
    buf.writeln(
      'Property,Unit Number,Invite Code,Code Status,Resident,Signup Steps',
    );
    for (final p in _properties) {
      final propName = p['name']?.toString() ?? '';
      final units = List<Map<String, dynamic>>.from(
        p['units_overview'] as List? ?? [],
      );
      for (final u in units) {
        final unitNum = u['unit_number']?.toString() ?? '';
        final code = u['invite_code']?.toString() ?? '';
        final claimed = u['invite_claimed'] == true;
        final resident = u['resident_name']?.toString() ?? '';
        final status = code.isEmpty
            ? 'No code yet'
            : (claimed ? 'Used' : 'Open');
        final steps = code.isEmpty
            ? 'Ask super admin to generate a code for this unit'
            : 'Login → Resident → select property → unit $unitNum → code $code';
        buf.writeln(
          '"${_csvCell(propName)}","${_csvCell(unitNum)}","${_csvCell(code)}",'
          '"${_csvCell(status)}","${_csvCell(resident)}","${_csvCell(steps)}"',
        );
      }
    }
    if (buf.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No units to export yet')),
      );
      return;
    }
    final safeName = _properties.isNotEmpty
        ? (_properties.first['name']?.toString() ?? 'property')
            .replaceAll(RegExp(r'[^\w\-]+'), '_')
        : 'property';
    try {
      await downloadCsv(
        buf.toString(),
        '${safeName}_resident_invite_codes.csv',
        sharePositionOrigin: _shareOrigin(),
      );
    } catch (e) {
      // Native export writes a file and opens the share sheet; on web it
      // triggers a download. Either can fail, and this used to be a plain
      // fire-and-forget call, so a failure showed the user nothing.
      ErrorReporter.showError(mounted ? context : null,
          'Could not export the unit codes - please try again',
          error: e, logContext: 'csv export: unit codes');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV downloaded — share with residents or your team'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _csvCell(String value) => value.replaceAll('"', '""');

  void _copyUnitCode(String unitNum, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied code for unit $unitNum'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openNotificationSender({String? propertyId, String mode = 'property'}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleNotificationSenderScreen(
          initialPropertyId: propertyId,
          initialMode: mode,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildTab()),
            RoleBottomNav(
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              accent: AppColors.manager,
              items: const [
                RoleNavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'Dashboard'),
                RoleNavItem(icon: Icons.apartment_outlined, activeIcon: Icons.apartment, label: 'Properties'),
                RoleNavItem(icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'Inbox'),
                RoleNavItem(icon: Icons.more_horiz, activeIcon: Icons.more_horiz, label: 'More'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    switch (_tabIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildPropertiesTab();
      case 2:
        return _buildRequestsTab();
      default:
        return _buildMoreTab();
    }
  }

  // ── Dashboard tab ─────────────────────────────────────────────────────────────

  Widget _buildDashboardTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: [
          SkeletonCard(height: 128),
          SizedBox(height: 12),
          SkeletonCard(height: 60),
          SizedBox(height: 16),
          SkeletonCard(height: 110),
          SizedBox(height: 16),
          SkeletonCard(height: 110),
        ],
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlowBadge(label: _error!, accent: AppColors.error, showDot: false),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apartment_outlined, size: 56, color: _c.textMuted),
            SizedBox(height: 16),
            Text(
              'No properties assigned',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'A super admin must assign you to a property.',
              style: TextStyle(fontSize: 13, color: _c.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.rlvBlue,
      backgroundColor: _c.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Property Manager View',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _c.textPrimary,
                ),
              ),
              _buildAllPropertiesPill(),
            ],
          ),
          const SizedBox(height: 20),
          _buildRequestCard(
            label: 'Pending Comebacks',
            subtitle: 'Residents asked for a re-pickup',
            count: _pendingComebackCount,
            linkLabel: 'View inbox',
            onTap: () => setState(() => _tabIndex = 2),
            countColor:
                _pendingComebackCount > 0 ? AppColors.warning : AppColors.rlvBlue,
          ),
          const SizedBox(height: 20),
          // Announcements section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ANNOUNCEMENTS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: _c.textSecondary,
                ),
              ),
              if (_recentAnnouncements.isNotEmpty)
                TextButton(
                  onPressed: _showAnnouncementSheet,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'New +',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.rlvBlue),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentAnnouncements.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _c.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined, size: 20, color: _c.textSecondary),
                  const SizedBox(width: 12),
                  Text(
                    'No announcements yet',
                    style: GoogleFonts.inter(fontSize: 13, color: _c.textSecondary),
                  ),
                ],
              ),
            )
          else
            ..._recentAnnouncements.map((a) => _buildAnnouncementRow(a)),
          const SizedBox(height: 20),
          // Send Announcement button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _showAnnouncementSheet,
              icon: const Icon(Icons.campaign_outlined),
              label: Text(
                'Send Community Announcement',
                style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.rlvBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          // Compliance / satisfaction metrics
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: BentoCard(
                  height: 100,
                  child: MetricTile(
                    label: 'Pickup SLA',
                    value: '${(_serviceCompliance * 100).toStringAsFixed(0)}%',
                    subtitle: 'Nightly runs completed',
                    valueColor: _serviceCompliance >= 0.9
                        ? AppColors.success
                        : _serviceCompliance >= 0.7
                            ? AppColors.warning
                            : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoCard(
                  height: 100,
                  child: MetricTile(
                    label: 'Satisfaction',
                    value: _avgSatisfaction > 0 ? _avgSatisfaction.toStringAsFixed(1) : '--',
                    valueColor: _avgSatisfaction >= 4
                        ? AppColors.success
                        : _avgSatisfaction >= 3
                            ? AppColors.warning
                            : _avgSatisfaction > 0
                                ? AppColors.error
                                : _c.textPrimary,
                    subtitle: _avgSatisfaction > 0
                        ? 'Avg resident rating / 5'
                        : 'No ratings yet',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllPropertiesPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'All Properties',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _c.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: _c.textSecondary),
        ],
      ),
    );
  }

  Widget _buildRequestCard({
    required String label,
    String? subtitle,
    required int count,
    required String linkLabel,
    required VoidCallback? onTap,
    required Color countColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 13, color: _c.textSecondary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: _c.textMuted),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: countColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('$linkLabel ›', style: GoogleFonts.inter(fontSize: 13, color: AppColors.rlvBlue)),
            )
          else
            Text(linkLabel, style: GoogleFonts.inter(fontSize: 13, color: _c.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAnnouncementRow(Map<String, dynamic> a) {
    final title = a['title']?.toString() ?? '';
    final body = a['body']?.toString() ?? '';
    final createdAt = a['created_at']?.toString() ?? '';
    String dateLabel = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateLabel = '${dt.month}/${dt.day}';
    } catch (e) {
      ErrorReporter.logSilent('property_manager_dashboard_new._buildAnnouncementRow', e);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: GoogleFonts.inter(fontSize: 11, color: _c.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(dateLabel, style: GoogleFonts.inter(fontSize: 11, color: _c.textSecondary)),
          ],
        ],
      ),
    );
  }

  Future<void> _showAnnouncementSheet() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedPropertyId =
        _properties.isNotEmpty ? _properties.first['id'] as String? : null;
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Send Announcement',
                  style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Residents will see this in their Community Updates feed',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              if (_properties.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: selectedPropertyId,
                  dropdownColor: AppColors.surface2,
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Property',
                    labelStyle: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  items: _properties
                      .map((p) => DropdownMenuItem<String>(
                            value: p['id'] as String?,
                            child: Text(p['name']?.toString() ?? ''),
                          ))
                      .toList(),
                  onChanged: (v) => setModal(() => selectedPropertyId = v),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final body = bodyCtrl.text.trim();
                          if (title.isEmpty || body.isEmpty) return;
                          setModal(() => sending = true);
                          try {
                            final uid = Supabase.instance.client.auth
                                .currentUser?.id;
                            await Supabase.instance.client
                                .from('community_announcements')
                                .insert({
                              'property_id': selectedPropertyId,
                              'title': title,
                              'body': body,
                              'sent_by': uid,
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            _snack('Announcement sent!');
                          } catch (e) {
                            setModal(() => sending = false);
                            _snack('Failed to send: $e');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rlvBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text('Send Announcement',
                          style: GoogleFonts.montserrat(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface1,
      content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
    ));
  }

  // ignore: unused_element
  Widget _buildPropertyCard(Map<String, dynamic> p) {
    final violations = p['violation_count'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name']?.toString() ?? 'Property',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p['service_window']?.toString() ?? '--',
                      style: TextStyle(
                        fontSize: 12,
                        color: _c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (violations > 0)
                GlowBadge(
                  label: '$violations violations',
                  accent: AppColors.error,
                  showDot: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOccupancyBillingBanner(p),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                    '${p['occupied_count'] ?? p['resident_count'] ?? 0}/${p['unit_count'] ?? 0}',
                    'Occupied',
                    AppColors.manager),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                    '${p['billable_doors'] ?? 0}',
                    'Billable',
                    AppColors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                    '\$${(p['est_monthly_bill'] as num? ?? 0).toStringAsFixed(0)}',
                    'Est / mo',
                    AppColors.info),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNotificationSender(
                    propertyId: p['id']?.toString(),
                    mode: 'property',
                  ),
                  icon: const Icon(Icons.campaign_outlined, size: 16),
                  label: const Text('Alert All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.manager,
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openNotificationSender(
                    propertyId: p['id']?.toString(),
                    mode: 'user',
                  ),
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('1 Resident'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _c.textSecondary,
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyBillingBanner(Map<String, dynamic> p) {
    final total = p['unit_count'] as int? ?? 0;
    final occupied = p['occupied_count'] as int? ?? p['resident_count'] as int? ?? 0;
    final billable = p['billable_doors'] as int? ?? 0;
    final minPctFraction = (p['min_billable_pct'] as num? ?? 0.85).toDouble();
    final minPctDisplay = (minPctFraction * 100).round();
    final occPct = ((p['occupancy_pct'] as num? ?? 0) * 100).round();
    final meetsMin = total == 0 ||
        billable <= occupied ||
        occupied >= PropertyBilling.minimumBillableDoors(total, minPctFraction);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (meetsMin ? AppColors.info : AppColors.warning)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (meetsMin ? AppColors.info : AppColors.warning)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        total == 0
            ? 'Ask super admin to set total doors under Property Billing Rates.'
            : '$occupied of $total doors occupied ($occPct%). '
                'You are billed for $billable billable doors '
                '($minPctDisplay% minimum = '
                '${PropertyBilling.minimumBillableDoors(total, minPctFraction)} doors, '
                'or more if occupancy is higher).',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: _c.textSecondary,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: _c.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Properties tab ───────────────────────────────────────────────────────────

  Widget _buildPropertiesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Units & Invite Codes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GlowBadge(
                label: '${_properties.length} properties',
                accent: AppColors.manager,
                showDot: false,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            'Codes appear here automatically after super admin generates them in '
            'Resident Invite Codes (same database — refresh if you just added codes).',
            style: GoogleFonts.inter(fontSize: 12, color: _c.textSecondary, height: 1.35),
          ),
        ),
        if (!_loading && _properties.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: OutlinedButton.icon(
              onPressed: _exportUnitCodesCsv,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Export unit codes (CSV)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.manager,
                side: BorderSide(color: AppColors.manager.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        if (_loading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                SkeletonCard(height: 66),
                SizedBox(height: 10),
                SkeletonCard(height: 66),
              ],
            ),
          )
        else if (_properties.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No properties assigned',
                style: TextStyle(color: _c.textMuted, fontSize: 14),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.manager,
              backgroundColor: _c.surface1,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  for (final p in _properties) ...[
                    _buildPropertyUnitsSection(p),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPropertyUnitsSection(Map<String, dynamic> property) {
    final units = List<Map<String, dynamic>>.from(
      property['units_overview'] as List? ?? [],
    );
    final propName = property['name']?.toString() ?? 'Property';
    final total = property['unit_count'] as int? ?? units.length;
    final occupied = property['occupied_count'] as int? ?? 0;
    final billable = property['billable_doors'] as int? ?? 0;
    final estBill = property['est_monthly_bill'] as num? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    propName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _c.textPrimary,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$occupied / $total occupied',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _c.textPrimary,
                      ),
                    ),
                    Text(
                      'Bill $billable doors · \$${estBill.toStringAsFixed(0)}/mo',
                      style: TextStyle(fontSize: 11, color: _c.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _buildOccupancyBillingBanner(property),
          ),
          if (units.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No units set up yet. Ask your super admin to add buildings, floors, and units, then generate invite codes per unit.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _c.textMuted,
                  height: 1.35,
                ),
              ),
            )
          else
            ...units.map((u) => _buildUnitRow(u)),
        ],
      ),
    );
  }

  Widget _buildUnitRow(Map<String, dynamic> unit) {
    final unitNum = unit['unit_number']?.toString() ?? '—';
    final resident = unit['resident_name']?.toString();
    final isOccupied = unit['is_occupied'] == true;
    final code = unit['invite_code']?.toString();
    final claimed = unit['invite_claimed'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.manager.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              unitNum,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.manager,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit $unitNum',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOccupied && resident != null
                      ? 'Resident: $resident'
                      : 'Vacant — not occupied',
                  style: TextStyle(fontSize: 12, color: _c.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  code != null
                      ? 'Signup code: $code'
                      : 'No signup code yet (super admin generates per unit)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: code != null ? _c.textPrimary : _c.textMuted,
                    fontWeight: code != null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: isOccupied ? 'Occupied' : 'Vacant',
            accent: isOccupied ? AppColors.success : _c.textMuted,
            showDot: isOccupied,
          ),
          const SizedBox(width: 6),
          if (code != null) ...[
            IconButton(
              tooltip: 'Copy code',
              icon: Icon(Icons.copy_outlined, size: 20, color: _c.textSecondary),
              onPressed: () => _copyUnitCode(unitNum, code),
            ),
            GlowBadge(
              label: claimed ? 'Code used' : 'Code open',
              accent: claimed ? AppColors.info : AppColors.manager,
              showDot: !claimed,
            ),
          ],
        ],
      ),
    );
  }

  // ── Requests tab ─────────────────────────────────────────────────────────────

  Widget _buildRequestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Inbox',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Pending comeback pickups residents requested in the app.',
            style: GoogleFonts.inter(fontSize: 12, color: _c.textSecondary),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.manager,
            backgroundColor: _c.surface1,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                if (_pendingComebacks.isEmpty)
                  _buildInboxEmpty(
                      'No pending comeback pickups for your properties.')
                else
                  ..._pendingComebacks.map((r) => _buildComebackRow(r)),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Alert All Residents',
                  onPressed: () => _openNotificationSender(mode: 'property'),
                  accent: AppColors.manager,
                  icon: Icons.campaign_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInboxEmpty(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(fontSize: 13, color: _c.textMuted),
      ),
    );
  }

  Widget _buildComebackRow(Map<String, dynamic> row) {
    final pickup = row['pickups'];
    String unitLabel = 'Unit —';
    if (pickup is Map) {
      final units = pickup['units'];
      if (units is Map) {
        final n = units['unit_number']?.toString();
        if (n != null) unitLabel = 'Unit $n';
      }
    }
    final isFree = row['is_free'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comeback pickup',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unitLabel,
                  style: TextStyle(fontSize: 12, color: _c.textSecondary),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: isFree ? 'Free' : 'Paid',
            accent: isFree ? AppColors.success : AppColors.info,
            showDot: false,
          ),
        ],
      ),
    );
  }

  // ── More tab ───────────────────────────────────────────────────────────────

  Widget _buildMoreTab() {
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : 'M';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'More',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _c.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _c.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.manager.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.manager,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _email,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_properties.length} propert${_properties.length == 1 ? 'y' : 'ies'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: 'PM',
                      accent: AppColors.manager,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('REPORTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _c.textMuted,
                      letterSpacing: 1.2)),
              const SizedBox(height: 10),
              ..._properties.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: _c.surface1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _c.border),
                      ),
                      leading: const Icon(Icons.bar_chart_outlined,
                          color: AppColors.manager, size: 22),
                      title: Text(p['name']?.toString() ?? '',
                          style: TextStyle(
                              color: _c.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('Service history & SLA',
                          style: TextStyle(
                              color: _c.textSecondary, fontSize: 12)),
                      trailing: Icon(Icons.chevron_right,
                          color: _c.textMuted, size: 20),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PmComplianceReportScreen(
                                    propertyId: p['id']?.toString() ?? '',
                                    propertyName:
                                        p['name']?.toString() ?? '',
                                  ))),
                    ),
                  )),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Change Password',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen()),
                ),
                accent: AppColors.info,
                icon: Icons.lock_reset_outlined,
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Sign Out',
                onPressed: _signOut,
                accent: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

}
