import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/role_hero_card.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../manager/screens/manager_dashboard_screen.dart';
import '../../manager/screens/property_manager_dashboard_new.dart';
import '../../manager/screens/simple_notification_sender_screen.dart';
import '../../resident/screens/resident_dashboard_screen.dart';
import '../../worker/screens/worker_dashboard_screen.dart';

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

  AppColorsScheme _c = AppColorsScheme.dark;

  int get _totalProperties => _properties.length;
  int get _totalUnits =>
      _properties.fold(0, (s, p) => s + (p['unit_count'] as int? ?? 0));
  int get _totalResidents =>
      _properties.fold(0, (s, p) => s + (p['resident_count'] as int? ?? 0));
  int get _totalInvitesIssued =>
      _properties.fold(0, (s, p) => s + (p['invite_count'] as int? ?? 0));
  int get _totalInvitesUsed =>
      _properties.fold(0, (s, p) => s + (p['claimed_count'] as int? ?? 0));

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
              'id, name, service_window_start, service_window_end, is_active, city, state')
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

        final sw = prop['service_window_start'] ?? '18:00';
        final ew = prop['service_window_end'] ?? '22:00';

        properties.add({
          'id': propId,
          'name': propName,
          'location': '${prop['city'] ?? ''}, ${prop['state'] ?? ''}',
          'service_window': '${_fmtTime(sw)} – ${_fmtTime(ew)}',
          'unit_count': unitCount,
          'resident_count': residentCount,
          'invite_count': invites.length,
          'claimed_count': claimedCount,
          'unclaimed_count': unitCount - residentCount,
        });
      }));

      properties.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String));

      setState(() => _properties = properties);
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

  // ── Build ─────────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          RoleHeroCard(
            accent: AppColors.owner,
            eyebrow: 'PORTFOLIO',
            title:
                '$_totalProperties Propert${_totalProperties == 1 ? 'y' : 'ies'}',
            subtitle:
                '$_totalResidents residents · $_totalUnits units · $activationRate activation',
            badgeLabel: 'Owner',
            showDot: false,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(value: '$_totalProperties', label: 'Properties'),
              const SizedBox(width: 8),
              StatTile(value: '$_totalUnits', label: 'Units'),
              const SizedBox(width: 8),
              StatTile(value: '$_totalResidents', label: 'Residents'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StatTile(value: '$_totalInvitesIssued', label: 'Codes Issued'),
              const SizedBox(width: 8),
              StatTile(
                value: '$_totalInvitesUsed',
                label: 'Codes Used',
                valueColor: AppColors.success,
              ),
              const SizedBox(width: 8),
              StatTile(value: activationRate, label: 'Activation'),
            ],
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
                  onPressed: () => setState(() => _tabIndex = 1),
                  child: Text(
                    'View all ${_properties.length} properties →',
                    style: TextStyle(color: AppColors.owner),
                  ),
                ),
              ),
            ],
          ],
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
                separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final claimed = p['claimed_count'] as int? ?? 0;
    final issued = p['invite_count'] as int? ?? 0;
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
              _ownerMiniStat('$units', 'Units', AppColors.info),
              const SizedBox(width: 8),
              _ownerMiniStat('$residents', 'Residents', AppColors.owner),
              const SizedBox(width: 8),
              _ownerMiniStat('$claimed/$issued', 'Codes', AppColors.warning),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.attach_money, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'Financials',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Stripe Connect payouts and revenue\nreporting will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
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
