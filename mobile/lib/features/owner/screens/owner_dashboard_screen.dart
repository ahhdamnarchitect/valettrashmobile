import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/billing/property_billing.dart';
import '../../../core/workforce/clock_hours.dart';
import '../../../core/platform/csv_download_stub.dart'
    if (dart.library.html) '../../../core/platform/csv_download_web.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/metric_tile.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../manager/screens/manager_dashboard_screen.dart';
import '../../manager/screens/property_manager_dashboard_new.dart';
import '../../manager/screens/simple_notification_sender_screen.dart';
import '../../resident/screens/resident_dashboard_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../shared/screens/service_requests_inbox_screen.dart';
import '../../worker/screens/worker_dashboard_screen.dart';
import 'owner_workforce_screen.dart';
import '../widgets/owner_admin_switch_bar.dart';
import '../../../core/utils/error_reporter.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  String _email = '';

  List<Map<String, dynamic>> _properties = [];
  int _completedComebacks = 0;
  double _avgSatisfaction = 0;
  int _lastMonthCompletedComebacks = 0;
  double _lastMonthAvgSatisfaction = 0;

  double _estContractRevenueMonthly = 0;
  double _residentMrr = 0;
  double _paidInvoicesTotal = 0;
  double _paidComebacksTotal = 0;
  double _contractorPayoutsTotal = 0;
  double _portfolioRevenuePerDoor = 0;
  int _portfolioBillableDoors = 0;
  List<Map<String, dynamic>> _stripePayouts = [];
  double _laborWeekHours = 0;
  double _laborWeekCost = 0;
  double _laborMonthCost = 0;

  AppColorsScheme _c = AppColorsScheme.dark;

  int get _totalProperties => _properties.length;
  int get _totalUnits =>
      _properties.fold(0, (s, p) => s + (p['unit_count'] as int? ?? 0));
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
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final client = Supabase.instance.client;

    try {
      final propsRows = await client
          .from('properties')
          .select(
              'id, name, service_window_start, service_window_end, is_active, city, state, monthly_fee_per_door, minimum_billable_occupancy_percent, billing_total_doors, billing_occupied_doors')
          .eq('is_active', true)
          .order('name');

      final rows = List<Map<String, dynamic>>.from(propsRows as List);
      final List<Map<String, dynamic>> properties = [];

      await Future.wait(rows.map((prop) async {
        final propId = prop['id']?.toString() ?? '';
        final propName = prop['name']?.toString() ?? '';

        final results = await Future.wait(<Future<dynamic>>[
          client
              .from('resident_units')
              .select('id')
              .eq('property_id', propId)
              .eq('is_active', true),
          client
              .from('invite_codes')
              .select('id, assigned_user_id')
              .eq('property_id', propId),
          _unitCountForProperty(propId),
        ]);

        final residentCount = (results[0] as List).length;
        final invites = List<Map<String, dynamic>>.from(results[1] as List);
        final unitCount = results[2] as int;
        final claimedCount =
            invites.where((i) => i['assigned_user_id'] != null).length;
        final billingSnap = PropertyBilling.snapshot(
          property: prop,
          countedUnits: unitCount,
          countedOccupied: residentCount,
        );
        final billableDoors = billingSnap['billable_doors'] as int;
        final contractMonthly = billingSnap['monthly_amount'] as double;
        final totalForBilling = billingSnap['total_doors'] as int;
        final occupiedForBilling = billingSnap['occupied_doors'] as int;

        final sw = prop['service_window_start'] ?? '18:00';
        final ew = prop['service_window_end'] ?? '22:00';

        properties.add({
          'id': propId,
          'name': propName,
          'location': '${prop['city'] ?? ''}, ${prop['state'] ?? ''}',
          'service_window': '${_fmtTime(sw)} – ${_fmtTime(ew)}',
          'unit_count': totalForBilling,
          'unit_count_in_app': unitCount,
          'resident_count': residentCount,
          'occupied_count': occupiedForBilling,
          'billable_doors': billableDoors,
          'occupancy_pct': billingSnap['occupancy_percent'],
          'fee_per_door': billingSnap['fee_per_door'],
          'min_billable_pct': billingSnap['min_billable_percent'],
          'contract_monthly': contractMonthly,
          'resident_mrr': 0.0,
          'paid_invoices': 0.0,
          'paid_comebacks': 0.0,
          'total_property_revenue': contractMonthly,
          'revenue_per_door': PropertyBilling.revenuePerBillableDoor(
            totalRevenue: contractMonthly,
            billableDoors: billableDoors,
          ),
          'invite_count': invites.length,
          'claimed_count': claimedCount,
          'unclaimed_count': unitCount - residentCount,
        });
      }));

      final allPropIds =
          properties.map((p) => p['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();

      if (allPropIds.isNotEmpty) {
        final mrrByProp = <String, double>{};
        final invoicesByProp = <String, double>{};
        final comebacksByProp = <String, double>{};

        try {
          final subs = await client
              .from('subscriptions')
              .select('property_id, monthly_fee, status')
              .filter('property_id', 'in', '(${allPropIds.join(',')})')
              .eq('status', 'active');
          for (final s in subs as List) {
            final pid = s['property_id']?.toString();
            if (pid == null) continue;
            mrrByProp[pid] =
                (mrrByProp[pid] ?? 0) + ((s['monthly_fee'] as num?)?.toDouble() ?? 0);
          }
        } catch (e) {
          ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
        }

        try {
          final inv = await client
              .from('invoices')
              .select('property_id, amount, status')
              .filter('property_id', 'in', '(${allPropIds.join(',')})')
              .eq('status', 'paid');
          for (final i in inv as List) {
            final pid = i['property_id']?.toString();
            if (pid == null) continue;
            invoicesByProp[pid] =
                (invoicesByProp[pid] ?? 0) + ((i['amount'] as num?)?.toDouble() ?? 0);
          }
        } catch (e) {
          ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
        }

        try {
          final paidCb = await client
              .from('missed_pickup_requests')
              .select('payment_amount_cents, payment_status, pickups(property_id)')
              .eq('payment_status', 'paid');
          for (final r in paidCb as List) {
            final pickup = r['pickups'];
            if (pickup is! Map) continue;
            final pid = pickup['property_id']?.toString();
            if (pid == null || !allPropIds.contains(pid)) continue;
            final cents = (r['payment_amount_cents'] as num?)?.toDouble() ?? 0;
            comebacksByProp[pid] = (comebacksByProp[pid] ?? 0) + cents / 100;
          }
        } catch (e) {
          ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
        }

        for (final p in properties) {
          final pid = p['id']?.toString() ?? '';
          final mrr = mrrByProp[pid] ?? 0;
          final invPaid = invoicesByProp[pid] ?? 0;
          final cbPaid = comebacksByProp[pid] ?? 0;
          final contract = (p['contract_monthly'] as num?)?.toDouble() ?? 0;
          final billable = p['billable_doors'] as int? ?? 0;
          final totalRev = contract + mrr + invPaid + cbPaid;
          p['resident_mrr'] = mrr;
          p['paid_invoices'] = invPaid;
          p['paid_comebacks'] = cbPaid;
          p['total_property_revenue'] = totalRev;
          p['revenue_per_door'] = PropertyBilling.revenuePerBillableDoor(
            totalRevenue: totalRev,
            billableDoors: billable,
          );
        }
      }

      double estContract = 0;
      double mrrTotal = 0;
      double invTotal = 0;
      double cbTotal = 0;
      int billableTotal = 0;
      double revenueTotal = 0;
      for (final p in properties) {
        estContract += (p['contract_monthly'] as num?)?.toDouble() ?? 0;
        mrrTotal += (p['resident_mrr'] as num?)?.toDouble() ?? 0;
        invTotal += (p['paid_invoices'] as num?)?.toDouble() ?? 0;
        cbTotal += (p['paid_comebacks'] as num?)?.toDouble() ?? 0;
        billableTotal += p['billable_doors'] as int? ?? 0;
        revenueTotal += (p['total_property_revenue'] as num?)?.toDouble() ?? 0;
      }

      List<Map<String, dynamic>> payouts = [];
      double payoutSum = 0;
      try {
        final payoutRows = await client
            .from('contractor_payouts')
            .select(
                'id, amount, status, payout_type, stripe_payout_id, created_at, properties(name)')
            .order('created_at', ascending: false)
            .limit(15);
        payouts = List<Map<String, dynamic>>.from(payoutRows as List);
        for (final row in payouts) {
          if (row['status'] == 'paid' || row['status'] == 'processing') {
            payoutSum += (row['amount'] as num?)?.toDouble() ?? 0;
          }
        }
      } catch (e) {
        ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
      }

      double laborWeekH = 0;
      double laborWeekC = 0;
      double laborMonthC = 0;
      try {
        final driverRows = await client
            .from('users')
            .select('id, hourly_rate')
            .eq('role', 'driver')
            .eq('is_active', true);
        final drivers = List<Map<String, dynamic>>.from(driverRows as List);
        final driverIds = drivers
            .map((d) => d['id']?.toString())
            .whereType<String>()
            .toList();
        if (driverIds.isNotEmpty) {
          final since = ClockHours.monthStartLocal().toUtc().toIso8601String();
          final eventRows = await client
              .from('clock_events')
              .select('user_id, event_type, created_at')
              .filter('user_id', 'in', '(${driverIds.join(',')})')
              .gte('created_at', since)
              .order('created_at', ascending: true);
          final events =
              List<Map<String, dynamic>>.from(eventRows as List);
          final weekStart = ClockHours.weekStartLocal();
          final monthStart = ClockHours.monthStartLocal();
          for (final d in drivers) {
            final id = d['id']?.toString() ?? '';
            final rate = (d['hourly_rate'] as num?)?.toDouble() ?? 18.0;
            final userEvents =
                events.where((e) => e['user_id']?.toString() == id).toList();
            final shifts = ClockHours.shiftsFromEvents(userEvents);
            final wh = ClockHours.totalHours(shifts, since: weekStart);
            final mh = ClockHours.totalHours(shifts, since: monthStart);
            laborWeekH += wh;
            laborWeekC += ClockHours.laborCost(hours: wh, hourlyRate: rate);
            laborMonthC += ClockHours.laborCost(hours: mh, hourlyRate: rate);
          }
        }
      } catch (e) {
        ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
      }

      properties.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String));

      // Load completed comebacks across all properties
      int completedCb = 0;
      double avgRating = 0;
      if (rows.isNotEmpty) {
        final allPropIds = rows.map((r) => r['id']?.toString() ?? '').toList();
        try {
          final cbRows = await client
              .from('missed_pickup_requests')
              .select('id')
              .eq('status', 'completed');
          completedCb = (cbRows as List).length;
        } catch (e) {
          ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
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
            avgRating = sum / ratingList.length;
          }
        } catch (e) {
          ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
        }
      }

      // Month-over-month: last month's comebacks and satisfaction
      int lastMonthCb = 0;
      double lastMonthRating = 0;
      try {
        final now = DateTime.now();
        final firstOfThisMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
        final firstOfLastMonth = DateTime(now.year, now.month - 1, 1).toUtc().toIso8601String();

        final allPropIds2 = properties.map((p) => p['id'] as String).toList();

        final lastMonthComebacks = await client
            .from('missed_pickup_requests')
            .select('id')
            .gte('completed_at', firstOfLastMonth)
            .lt('completed_at', firstOfThisMonth)
            .eq('status', 'completed');
        lastMonthCb = (lastMonthComebacks as List).length;

        if (allPropIds2.isNotEmpty) {
          final lastMonthRatings = await client
              .from('satisfaction_ratings')
              .select('rating')
              .filter('property_id', 'in', '(${allPropIds2.join(',')})')
              .gte('created_at', firstOfLastMonth)
              .lt('created_at', firstOfThisMonth);
          final ratingList2 = lastMonthRatings as List;
          if (ratingList2.isNotEmpty) {
            final sum = ratingList2.fold<double>(0, (acc, r) => acc + (r['rating'] as int? ?? 0).toDouble());
            lastMonthRating = sum / ratingList2.length;
          }
        }
      } catch (e) {
        ErrorReporter.logSilent('owner_dashboard_screen.operation', e);
      }

      setState(() {
        _properties = properties;
        _completedComebacks = completedCb;
        _avgSatisfaction = avgRating;
        _lastMonthCompletedComebacks = lastMonthCb;
        _lastMonthAvgSatisfaction = lastMonthRating;
        _estContractRevenueMonthly = estContract;
        _residentMrr = mrrTotal;
        _paidInvoicesTotal = invTotal;
        _paidComebacksTotal = cbTotal;
        _contractorPayoutsTotal = payoutSum;
        _portfolioBillableDoors = billableTotal;
        _portfolioRevenuePerDoor = PropertyBilling.revenuePerBillableDoor(
          totalRevenue: revenueTotal,
          billableDoors: billableTotal,
        );
        _stripePayouts = payouts;
        _laborWeekHours = laborWeekH;
        _laborWeekCost = laborWeekC;
        _laborMonthCost = laborMonthC;
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

  void _openAdminPortal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        child: Column(
          children: [
            OwnerAdminSwitchBar(
              label: 'Admin Portal',
              subtitle: 'Users, properties, invite codes',
              icon: Icons.admin_panel_settings_outlined,
              accent: AppColors.owner,
              onTap: _openAdminPortal,
            ),
            Expanded(child: _buildTab()),
            RoleBottomNav(
              currentIndex: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
              accent: AppColors.owner,
              items: const [
                RoleNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Overview',
                ),
                RoleNavItem(
                  icon: Icons.attach_money_outlined,
                  activeIcon: Icons.attach_money,
                  label: 'Financials',
                ),
                RoleNavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Reports',
                ),
                RoleNavItem(
                  icon: Icons.more_horiz,
                  activeIcon: Icons.more_horiz,
                  label: 'More',
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
        return _buildOverviewTab();
      case 1:
        return _buildFinancialsTab();
      case 2:
        return _buildReportsTab();
      default:
        return _buildMoreTab();
    }
  }

  // ── Overview tab ──────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: _c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }
    final activationRate = _totalUnits > 0
        ? '${(_totalResidents / _totalUnits * 100).toStringAsFixed(1)}%'
        : '—';

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.owner,
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
                'Portfolio Summary',
                style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w800, color: _c.textPrimary),
              ),
              _buildThisMonthPill(),
            ],
          ),
          const SizedBox(height: 20),
          // Communities / Total Units row
          Row(children: [
            Expanded(child: BentoCard(height: 90, child: MetricTile(label: 'Communities', value: '$_totalProperties'))),
            const SizedBox(width: 12),
            Expanded(child: BentoCard(height: 90, child: MetricTile(label: 'Total Units', value: '$_totalUnits'))),
          ]),
          const SizedBox(height: 12),
          // Service Savings with delta
          _buildSavingsCard(),
          const SizedBox(height: 12),
          // Satisfaction with delta
          _buildSatisfactionBento(),
          const SizedBox(height: 12),
          // Activation bento
          BentoCard(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ACTIVATION RATE',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(activationRate,
                        style: GoogleFonts.montserrat(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.0)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$_totalResidents residents',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Text('$_totalUnits units',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          if (_properties.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _OwnerSectionLabel(text: 'PROPERTIES AT A GLANCE'),
            const SizedBox(height: 10),
            ..._properties.take(3).map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildCompactPropertyCard(p),
                )),
            if (_properties.length > 3) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _tabIndex = 2),
                  child: Text(
                    'View all ${_properties.length} properties →',
                    style: const TextStyle(color: AppColors.rlvBlue),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildThisMonthPill() {
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
          Text('This Month', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _c.textPrimary)),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, size: 16, color: _c.textSecondary),
        ],
      ),
    );
  }

  Widget _buildSavingsCard() {
    final thisMonthSavings = _completedComebacks * 15;
    final lastMonthSavings = _lastMonthCompletedComebacks * 15;
    final delta = lastMonthSavings > 0
        ? ((thisMonthSavings - lastMonthSavings) / lastMonthSavings * 100).round()
        : 0;
    final hasDelta = lastMonthSavings > 0;

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
                Text('SERVICE SAVINGS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.textSecondary)),
                const SizedBox(height: 4),
                Text('\$$thisMonthSavings', style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800, color: _c.textPrimary, height: 1.0)),
                if (hasDelta)
                  Text('vs last month', style: GoogleFonts.inter(fontSize: 11, color: _c.textSecondary)),
              ],
            ),
          ),
          if (hasDelta)
            Row(
              children: [
                Icon(
                  delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: delta >= 0 ? AppColors.success : AppColors.error,
                ),
                Text(
                  '${delta.abs()}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: delta >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSatisfactionBento() {
    final satisfactionDisplay = _avgSatisfaction > 0 ? _avgSatisfaction.toStringAsFixed(1) : '--';
    final delta = (_lastMonthAvgSatisfaction > 0 && _avgSatisfaction > 0)
        ? ((_avgSatisfaction - _lastMonthAvgSatisfaction) / _lastMonthAvgSatisfaction * 100).round()
        : 0;
    final hasDelta = _lastMonthAvgSatisfaction > 0 && _avgSatisfaction > 0;
    final satisfColor = _avgSatisfaction >= 4 ? AppColors.success : _avgSatisfaction >= 3 ? AppColors.warning : _avgSatisfaction > 0 ? AppColors.error : _c.textPrimary;

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
                Text('RESIDENT SATISFACTION', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(satisfactionDisplay, style: GoogleFonts.montserrat(fontSize: 32, fontWeight: FontWeight.w800, color: satisfColor, height: 1.0)),
                    if (_avgSatisfaction > 0) ...[
                      const SizedBox(width: 4),
                      Text('/ 5', style: GoogleFonts.inter(fontSize: 14, color: _c.textSecondary)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (hasDelta)
            Row(
              children: [
                Icon(
                  delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: delta >= 0 ? AppColors.success : AppColors.error,
                ),
                Text(
                  '${delta.abs()}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: delta >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompactPropertyCard(Map<String, dynamic> p) {
    final units = p['unit_count'] as int? ?? 0;
    final residents = p['resident_count'] as int? ?? 0;
    final pct = units > 0
        ? '${(residents / units * 100).toStringAsFixed(0)}%'
        : '0%';
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
              color: AppColors.owner.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.apartment_outlined,
                size: 18, color: AppColors.owner),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name']?.toString() ?? 'Property',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$residents / $units residents',
                  style: TextStyle(
                      fontSize: 11, color: _c.textSecondary),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: pct,
            accent: AppColors.owner,
            showDot: false,
          ),
        ],
      ),
    );
  }

  // ── Reports tab ──────────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'All Properties',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _c.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GlowBadge(
                label: '$_totalProperties total',
                accent: AppColors.owner,
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
                SkeletonCard(height: 160),
                SizedBox(height: 12),
                SkeletonCard(height: 160),
              ],
            ),
          )
        else if (_properties.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.apartment_outlined,
                      size: 56, color: _c.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'No properties found',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.owner,
              backgroundColor: _c.surface1,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _properties.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _buildFullPropertyCard(_properties[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullPropertyCard(Map<String, dynamic> p) {
    final units = p['unit_count'] as int? ?? 0;
    final residents = p['resident_count'] as int? ?? 0;
    final pct = units > 0 ? residents / units : 0.0;
    final location = p['location'] as String? ?? '';
    final hasLocation = location.trim().isNotEmpty && location.trim() != ',';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.owner.withValues(alpha: 0.2),
        ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: TextStyle(
                            fontSize: 12, color: _c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              GlowBadge(
                label:
                    '${(pct * 100).toStringAsFixed(0)}% active',
                accent: pct >= 0.5 ? AppColors.success : AppColors.warning,
                showDot: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ownerMiniStat('$residents/$units', 'Occupied', AppColors.owner),
              const SizedBox(width: 8),
              _ownerMiniStat('${p['billable_doors'] ?? 0}', 'Billable', AppColors.warning),
              const SizedBox(width: 8),
              _ownerMiniStat(
                '\$${((p['revenue_per_door'] as num?) ?? 0).toStringAsFixed(0)}',
                '/ door',
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_outlined,
                  size: 13, color: _c.textMuted),
              const SizedBox(width: 4),
              Text(
                p['service_window']?.toString() ?? '--',
                style: TextStyle(
                    fontSize: 11, color: _c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SimpleNotificationSenderScreen(
                    initialPropertyId: p['id']?.toString(),
                    initialMode: 'property',
                  ),
                ),
              ),
              icon: const Icon(Icons.campaign_outlined, size: 16),
              label: const Text('Alert All Residents'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.owner,
                side: BorderSide(color: AppColors.owner.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Financials tab ────────────────────────────────────────────────────────────

  Widget _buildFinancialsTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          SkeletonCard(height: 90),
          SizedBox(height: 12),
          SkeletonCard(height: 120),
        ],
      );
    }

    final grossMonthly = _estContractRevenueMonthly +
        _residentMrr +
        _paidInvoicesTotal +
        _paidComebacksTotal;
    final netEst =
        grossMonthly - _contractorPayoutsTotal - _laborMonthCost;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.owner,
      backgroundColor: _c.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(
            'Financials',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contract revenue uses billable doors (85% minimum occupancy rule per property). '
            'Stripe Connect sync fills in automatically when webhooks are live.',
            style: GoogleFonts.inter(fontSize: 12, color: _c.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: BentoCard(
                  height: 96,
                  child: MetricTile(
                    label: 'Est contract / mo',
                    value: '\$${_estContractRevenueMonthly.toStringAsFixed(0)}',
                    subtitle: '$_portfolioBillableDoors billable doors',
                    valueColor: AppColors.owner,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoCard(
                  height: 96,
                  child: MetricTile(
                    label: 'Revenue / door',
                    value: _portfolioBillableDoors > 0
                        ? '\$${_portfolioRevenuePerDoor.toStringAsFixed(2)}'
                        : '—',
                    subtitle: 'All sources / billable',
                    valueColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BentoCard(
                  height: 96,
                  child: MetricTile(
                    label: 'Resident MRR',
                    value: '\$${_residentMrr.toStringAsFixed(0)}',
                    subtitle: 'Active subscriptions',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoCard(
                  height: 96,
                  child: MetricTile(
                    label: 'Net est / mo',
                    value: '\$${netEst.toStringAsFixed(0)}',
                    subtitle: 'After labor & payouts',
                    valueColor: netEst >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LABOR (FROM CLOCK)',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _c.textSecondary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OwnerWorkforceScreen(),
                  ),
                ),
                child: Text(
                  'Manage rates',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.owner,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BentoCard(
                  height: 88,
                  child: MetricTile(
                    label: 'Est labor (week)',
                    value: ClockHours.formatMoney(_laborWeekCost),
                    subtitle:
                        '${ClockHours.formatDuration(_laborWeekHours)} clocked',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BentoCard(
                  height: 88,
                  child: MetricTile(
                    label: 'Est labor (month)',
                    value: ClockHours.formatMoney(_laborMonthCost),
                    subtitle: 'Hours × hourly rates',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'REVENUE BY PROPERTY',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _c.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (_properties.isEmpty)
            Text('No properties', style: TextStyle(color: _c.textMuted))
          else
            ..._properties.map(_buildFinancialPropertyCard),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STRIPE CONNECT PAYOUTS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _c.textSecondary,
                ),
              ),
              TextButton(
                onPressed: _exportFinancialsCsv,
                child: Text(
                  'Export CSV',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.owner),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_stripePayouts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _c.surface1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _c.border),
              ),
              child: Text(
                'No contractor payouts recorded yet. When Stripe Connect is connected, '
                'payout rows with stripe_payout_id will list here.',
                style: GoogleFonts.inter(fontSize: 12, color: _c.textMuted, height: 1.35),
              ),
            )
          else
            ..._stripePayouts.map(_buildPayoutRow),
          const SizedBox(height: 12),
          _buildFinancialLine('Paid invoices (all time)', _paidInvoicesTotal),
          _buildFinancialLine('Paid comebacks (all time)', _paidComebacksTotal),
          _buildFinancialLine('Est labor (month, clock)', _laborMonthCost),
          _buildFinancialLine('Contractor payouts logged', _contractorPayoutsTotal),
        ],
      ),
    );
  }

  Widget _buildFinancialLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: _c.textSecondary)),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPropertyCard(Map<String, dynamic> p) {
    final units = p['unit_count'] as int? ?? 0;
    final occupied = p['occupied_count'] as int? ?? 0;
    final billable = p['billable_doors'] as int? ?? 0;
    final revPerDoor = (p['revenue_per_door'] as num?)?.toDouble() ?? 0;
    final totalRev = (p['total_property_revenue'] as num?)?.toDouble() ?? 0;
    final occPct = ((p['occupancy_pct'] as num? ?? 0) * 100).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border),
      ),
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
          const SizedBox(height: 8),
          Text(
            '$occupied / $units occupied ($occPct%) · $billable billable doors',
            style: TextStyle(fontSize: 12, color: _c.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ownerMiniStat(
                  '\$${totalRev.toStringAsFixed(0)}',
                  'Total rev',
                  AppColors.owner,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ownerMiniStat(
                  '\$${revPerDoor.toStringAsFixed(2)}',
                  '/ billable door',
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ownerMiniStat(
                  '\$${(p['contract_monthly'] as num? ?? 0).toStringAsFixed(0)}',
                  'Contract/mo',
                  AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(Map<String, dynamic> row) {
    final prop = row['properties'] is Map ? row['properties']['name']?.toString() : '';
    final stripeId = row['stripe_payout_id']?.toString();
    final status = row['status']?.toString() ?? '';
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _c.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${amount.toStringAsFixed(2)} · ${row['payout_type'] ?? 'payout'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _c.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  [if (prop != null && prop.isNotEmpty) prop, status, if (stripeId != null) 'Stripe ✓']
                      .join(' · '),
                  style: TextStyle(fontSize: 11, color: _c.textMuted),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: status,
            accent: status == 'paid' ? AppColors.success : AppColors.warning,
            showDot: false,
          ),
        ],
      ),
    );
  }

  Future<void> _exportFinancialsCsv() async {
    final buf = StringBuffer();
    buf.writeln(
      'Property,Total Units,Occupied,Billable Doors,Occupancy %,Fee Per Door,Contract Monthly,Resident MRR,Paid Invoices,Paid Comebacks,Total Revenue,Revenue Per Billable Door',
    );
    for (final p in _properties) {
      final occ = ((p['occupancy_pct'] as num? ?? 0) * 100).toStringAsFixed(1);
      buf.writeln(
        '"${p['name']}",${p['unit_count']},${p['occupied_count']},${p['billable_doors']},$occ,'
        '${p['fee_per_door']},${p['contract_monthly']},${p['resident_mrr']},${p['paid_invoices']},'
        '${p['paid_comebacks']},${p['total_property_revenue']},${p['revenue_per_door']}',
      );
    }
    try {
      await downloadCsv(buf.toString(), 'owner_financials_by_property.csv');
    } catch (e) {
      // Native export writes a file and opens the share sheet; on web it
      // triggers a download. Either can fail, and this used to be a plain
      // fire-and-forget call, so a failure showed the user nothing.
      ErrorReporter.showError(mounted ? context : null,
          'Could not export the financials - please try again',
          error: e, logContext: 'csv export: financials');
    }
  }

  // ── More tab ──────────────────────────────────────────────────────────────────

  Widget _buildMoreTab() {
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : 'O';
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
                      backgroundColor: AppColors.owner.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.owner,
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
                            '$_totalProperties propert${_totalProperties == 1 ? 'y' : 'ies'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _c.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: 'Owner',
                      accent: AppColors.owner,
                      showDot: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const _OwnerSectionLabel(text: 'SWITCH VIEW'),
              const SizedBox(height: 12),
              _buildRoleSwitchCard(
                label: 'Admin Portal',
                icon: Icons.admin_panel_settings_outlined,
                color: AppColors.owner,
                onTap: _openAdminPortal,
              ),
              const SizedBox(height: 20),
              const _OwnerSectionLabel(text: 'RESIDENT REQUESTS'),
              const SizedBox(height: 12),
              _buildRoleSwitchCard(
                label: 'Service Requests Inbox',
                icon: Icons.inbox_outlined,
                color: AppColors.owner,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServiceRequestsInboxScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _OwnerSectionLabel(text: 'SWITCH VIEW'),
              const SizedBox(height: 12),
              _buildRoleSwitchCard(
                label: 'Operations Manager',
                icon: Icons.admin_panel_settings_outlined,
                color: AppColors.manager,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManagerDashboardScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildRoleSwitchCard(
                label: 'Property Manager',
                icon: Icons.apartment_outlined,
                color: AppColors.manager,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const PropertyManagerDashboardNewScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildRoleSwitchCard(
                label: 'Worker (Driver)',
                icon: Icons.local_shipping_outlined,
                color: AppColors.worker,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WorkerDashboardScreen()),
                ),
              ),
              const SizedBox(height: 8),
              _buildRoleSwitchCard(
                label: 'Resident',
                icon: Icons.home_outlined,
                color: AppColors.resident,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ResidentDashboardScreen()),
                ),
              ),
              const SizedBox(height: 24),
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

  Widget _buildRoleSwitchCard({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: _c.textMuted),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _ownerMiniStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
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
      ),
    );
  }
}

class _OwnerSectionLabel extends StatelessWidget {
  final String text;
  const _OwnerSectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.roleColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
