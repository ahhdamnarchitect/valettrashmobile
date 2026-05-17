import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/role_hero_card.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/stat_tile.dart';
import 'pm_compliance_report_screen.dart';
import 'simple_notification_sender_screen.dart';

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
  List<Map<String, dynamic>> _inviteCodes = [];

  AppColorsScheme _c = AppColorsScheme.dark;

  int get _totalUnits =>
      _properties.fold(0, (s, p) => s + (p['unit_count'] as int? ?? 0));
  int get _totalResidents =>
      _properties.fold(0, (s, p) => s + (p['resident_count'] as int? ?? 0));
  int get _totalViolations =>
      _properties.fold(0, (s, p) => s + (p['violation_count'] as int? ?? 0));
  int get _totalComebacks =>
      _properties.fold(0, (s, p) => s + (p['comeback_count'] as int? ?? 0));
  int get _claimedCodes =>
      _inviteCodes.where((c) => c['assigned_user_id'] != null).length;

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
      final userPropsRows = await client
          .from('user_properties')
          .select(
            'property_id, properties(id, name, service_window_start, service_window_end, is_active)',
          )
          .eq('user_id', uid);

      final rows = List<Map<String, dynamic>>.from(userPropsRows as List);
      final List<Map<String, dynamic>> properties = [];
      final List<Map<String, dynamic>> allInviteCodes = [];

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
              .select('id, code, unit_id, assigned_user_id, use_count, max_uses')
              .eq('property_id', propId)
              .order('created_at', ascending: false)
              .limit(10),
          _unitCountForProperty(propId),
          _unitIdsForProperty(propId),
        ]);

        final residentCount = (results[0] as List).length;
        final propInvites =
            List<Map<String, dynamic>>.from(results[1] as List);
        final unitCount = results[2] as int;
        final unitIds = results[3] as List<String>;

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
          'unit_count': unitCount,
          'resident_count': residentCount,
          'violation_count': violationCount,
          'comeback_count': comebackCount,
          'invite_count': propInvites.length,
          'claimed_count': propInvites
              .where((c) => c['assigned_user_id'] != null)
              .length,
        });

        for (final ic in propInvites.take(6)) {
          allInviteCodes.add({...ic, 'property_id': propId, 'property_name': propName});
        }
      }

      setState(() {
        _properties = properties;
        _inviteCodes = allInviteCodes;
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
                RoleNavItem(
                  icon: Icons.apartment_outlined,
                  activeIcon: Icons.apartment,
                  label: 'Portfolio',
                ),
                RoleNavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Residents',
                ),
                RoleNavItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Notify',
                ),
                RoleNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                ),
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
        return _buildPortfolioTab();
      case 1:
        return _buildResidentsTab();
      case 2:
        return _buildNotifyTab();
      default:
        return _buildSettingsTab();
    }
  }

  // ── Portfolio tab ─────────────────────────────────────────────────────────────

  Widget _buildPortfolioTab() {
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
      color: AppColors.manager,
      backgroundColor: _c.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          RoleHeroCard(
            accent: AppColors.manager,
            eyebrow: 'PORTFOLIO',
            title: '${_properties.length} Propert${_properties.length == 1 ? 'y' : 'ies'}',
            subtitle: '$_totalResidents residents · $_totalUnits units',
            badgeLabel: 'Property Manager',
            showDot: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(value: '$_totalUnits', label: 'Units'),
              const SizedBox(width: 8),
              StatTile(value: '$_totalResidents', label: 'Residents'),
              const SizedBox(width: 8),
              StatTile(
                value: '$_totalViolations',
                label: 'Violations',
                valueColor: _totalViolations > 0 ? AppColors.error : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._properties.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPropertyCard(p),
              )),
        ],
      ),
    );
  }

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
          Row(
            children: [
              Expanded(
                child: _miniStat(
                    '${p['unit_count'] ?? 0}', 'Units', AppColors.info),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                    '${p['resident_count'] ?? 0}', 'Residents', AppColors.manager),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                    '${p['claimed_count'] ?? 0}/${p['invite_count'] ?? 0}',
                    'Codes',
                    AppColors.warning),
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

  // ── Residents tab ─────────────────────────────────────────────────────────────

  Widget _buildResidentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Residents & Codes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GlowBadge(
                label: '$_claimedCodes / ${_inviteCodes.length} claimed',
                accent: AppColors.manager,
                showDot: false,
              ),
            ],
          ),
        ),
        if (_loading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                SkeletonCard(height: 66),
                SizedBox(height: 10),
                SkeletonCard(height: 66),
                SizedBox(height: 10),
                SkeletonCard(height: 66),
              ],
            ),
          )
        else if (_inviteCodes.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_outlined,
                      size: 48, color: _c.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No invite codes issued yet',
                    style:
                        TextStyle(color: _c.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.manager,
              backgroundColor: _c.surface1,
              child: ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _inviteCodes.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _buildCodeCard(_inviteCodes[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCodeCard(Map<String, dynamic> item) {
    final isUsed = item['assigned_user_id'] != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.manager.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.vpn_key_outlined,
                size: 18, color: AppColors.manager),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['code']?.toString() ?? '--',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['property_name']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: _c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: isUsed ? 'Claimed' : 'Active',
            accent: isUsed ? AppColors.success : AppColors.manager,
            showDot: !isUsed,
          ),
        ],
      ),
    );
  }

  // ── Notify tab ───────────────────────────────────────────────────────────────

  Widget _buildNotifyTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Send Notifications',
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
              RoleHeroCard(
                accent: AppColors.manager,
                eyebrow: 'COMMUNICATION',
                title: 'Resident Alerts',
                subtitle:
                    'Send property-wide or individual notifications to residents',
                badgeLabel: 'Property Manager',
                showDot: false,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Alert All Residents',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SimpleNotificationSenderScreen(
                            initialMode: 'property'),
                  ),
                ),
                accent: AppColors.manager,
                icon: Icons.campaign_outlined,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SimpleNotificationSenderScreen(
                            initialMode: 'user'),
                  ),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Notify Specific Resident'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textSecondary,
                  side: BorderSide(color: _c.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Settings tab ──────────────────────────────────────────────────────────────

  Widget _buildSettingsTab() {
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : 'M';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Settings',
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

  // ── Legacy UI helpers (kept for internal use) ────────────────────────────────

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _inviteCodeRow(Map<String, dynamic> item) {
    final isUsed = item['assigned_user_id'] != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.meeting_room, color: Colors.blue.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item['property_name'] ?? ''}  •  ${item['code'] ?? ''}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isUsed ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUsed
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Text(
              isUsed ? 'Used' : 'Active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUsed
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
