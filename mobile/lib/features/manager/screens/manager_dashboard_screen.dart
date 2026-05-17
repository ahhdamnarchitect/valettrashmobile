import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../../core/utils/page_transitions.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/role_hero_card.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/stat_tile.dart';
import 'om_worker_map_screen.dart';
import 'simple_notification_sender_screen.dart';
import 'today_comebacks_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _error;
  String _email = '';

  List<String> _propertyIds = [];
  List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _runs = [];
  int _pendingComebacks = 0;
  int _acceptedComebacks = 0;
  int _completedComebacks = 0;
  List<Map<String, dynamic>> _comebackHistory = [];
  List<Map<String, dynamic>> _sentNotifications = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }
      _email = supabase.auth.currentUser?.email ?? '';

      final userPropsRows = await supabase
          .from('user_properties')
          .select('property_id')
          .eq('user_id', uid);

      final propIds = (userPropsRows as List)
          .map((r) => r['property_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (propIds.isEmpty) {
        setState(() {
          _propertyIds = [];
          _loading = false;
        });
        return;
      }

      _propertyIds = propIds;

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final todayStartUtc =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final sevenDaysAgoUtc =
          now.subtract(const Duration(days: 7)).toUtc().toIso8601String();

      final results = await Future.wait(<Future<dynamic>>[
        supabase
            .from('worker_assignments')
            .select('user_id, property_id, users(first_name, last_name, email)')
            .filter('property_id', 'in', '(${propIds.join(',')})')
            .eq('is_active', true),
        supabase
            .from('nightly_runs')
            .select(
                'id, status, property_id, started_at, completed_at, completed_units, total_units, properties(name)')
            .filter('property_id', 'in', '(${propIds.join(',')})')
            .eq('run_date', todayStr),
        supabase
            .from('missed_pickup_requests')
            .select('id, status')
            .gte('created_at', todayStartUtc),
        supabase
            .from('missed_pickup_requests')
            .select('id, status, completed_at, created_at')
            .gte('created_at', sevenDaysAgoUtc)
            .neq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(10),
        supabase
            .from('notifications')
            .select('id, title, created_at, type')
            .eq('sender_id', uid)
            .order('created_at', ascending: false)
            .limit(5),
      ]);

      final workerRows =
          List<Map<String, dynamic>>.from(results[0] as List);
      final runRows =
          List<Map<String, dynamic>>.from(results[1] as List);
      final comebackRows =
          List<Map<String, dynamic>>.from(results[2] as List);
      final historyRows =
          List<Map<String, dynamic>>.from(results[3] as List);
      final notifRows =
          List<Map<String, dynamic>>.from(results[4] as List);

      // De-duplicate workers by user_id (same driver can be assigned to multiple properties)
      final seenIds = <String>{};
      final uniqueWorkers = <Map<String, dynamic>>[];
      for (final row in workerRows) {
        final userId = row['user_id']?.toString() ?? '';
        if (userId.isNotEmpty && seenIds.add(userId)) {
          uniqueWorkers.add(row);
        }
      }

      setState(() {
        _workers = uniqueWorkers;
        _runs = runRows;
        _pendingComebacks =
            comebackRows.where((r) => r['status'] == 'pending').length;
        _acceptedComebacks =
            comebackRows.where((r) => r['status'] == 'accepted').length;
        _completedComebacks =
            comebackRows.where((r) => r['status'] == 'completed').length;
        _comebackHistory = historyRows;
        _sentNotifications = notifRows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _workerName(Map<String, dynamic> row) {
    final u = row['users'];
    if (u is! Map) return row['user_id']?.toString() ?? 'Unknown';
    final fn = u['first_name']?.toString() ?? '';
    final ln = u['last_name']?.toString() ?? '';
    if (fn.isNotEmpty || ln.isNotEmpty) return '$fn $ln'.trim();
    return u['email']?.toString() ?? 'Unknown';
  }

  Color _runStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _runStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'in_progress':
        return 'In Progress';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(String? isoStr) {
    if (isoStr == null) return '—';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.month}/${dt.day} ${_fmtTime(dt)}';
    } catch (_) {
      return isoStr;
    }
  }

  String _fmtTime(DateTime dt) {
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h12:$min $ap';
  }

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
                    style: const TextStyle(
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

  Widget _rowTile(Widget leading, String primary, [String? secondary]) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(primary,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(secondary,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRow(String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Overview',
                ),
                RoleNavItem(
                  icon: Icons.route_outlined,
                  activeIcon: Icons.route,
                  label: 'Routes',
                ),
                RoleNavItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Alerts',
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
        return _buildRoutesTab();
      case 2:
        return _buildAlertsTab();
      case 3:
        return _buildReportsTab();
      default:
        return _buildMoreTab();
    }
  }

  // ── Overview tab ─────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: const [
          SkeletonCard(height: 128),
          SizedBox(height: 12),
          SkeletonCard(height: 60),
          SizedBox(height: 16),
          SkeletonCard(height: 90),
          SizedBox(height: 16),
          SkeletonCard(height: 90),
        ],
      );
    }
    if (_propertyIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.apartment_outlined, size: 56, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'No properties assigned',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'A super admin must assign you to a property.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    final totalComebacks =
        _pendingComebacks + _acceptedComebacks + _completedComebacks;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.manager,
      backgroundColor: AppColors.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        children: [
          RoleHeroCard(
            accent: AppColors.manager,
            eyebrow: "TONIGHT'S OPERATIONS",
            title: '${_runs.length} Service Run${_runs.length == 1 ? '' : 's'}',
            subtitle:
                '${_workers.length} worker${_workers.length == 1 ? '' : 's'} · $totalComebacks comebacks',
            badgeLabel: _error != null ? 'Error' : 'Operations Manager',
            showDot: _error == null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(value: '${_workers.length}', label: 'Workers'),
              const SizedBox(width: 8),
              StatTile(value: '${_runs.length}', label: 'Runs'),
              const SizedBox(width: 8),
              StatTile(
                value: '$_pendingComebacks',
                label: 'Pending',
                valueColor: _pendingComebacks > 0 ? AppColors.warning : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_runs.isNotEmpty) ...[
            const _DarkSectionLabel(text: "TONIGHT'S RUNS"),
            const SizedBox(height: 8),
            ..._runs.map((run) => _buildRunCard(run)),
            const SizedBox(height: 20),
          ],
          if (_comebackHistory.isNotEmpty) ...[
            const _DarkSectionLabel(text: 'COMEBACK HISTORY (7 DAYS)'),
            const SizedBox(height: 8),
            ..._comebackHistory.take(5).map((h) => _buildHistoryCard(h)),
          ],
        ],
      ),
    );
  }

  Widget _buildRunCard(Map<String, dynamic> run) {
    final status = run['status'] as String? ?? 'in_progress';
    final prop = run['properties'];
    final propName =
        prop is Map ? prop['name']?.toString() ?? 'Unknown' : 'Unknown';
    final completed = run['completed_units'] as int? ?? 0;
    final total = run['total_units'] as int? ?? 0;
    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'in_progress':
        statusColor = AppColors.info;
        break;
      default:
        statusColor = AppColors.textMuted;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    propName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$completed / $total units',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            GlowBadge(
              label: _runStatusLabel(status),
              accent: statusColor,
              showDot: status == 'in_progress',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> h) {
    final status = h['status'] as String? ?? '';
    final date = _formatDate(
        h['completed_at'] as String? ?? h['created_at'] as String?);
    Color c;
    String label;
    if (status == 'completed') {
      c = AppColors.success;
      label = 'Completed';
    } else if (status == 'expired') {
      c = AppColors.error;
      label = 'Expired';
    } else {
      c = AppColors.warning;
      label = status;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            GlowBadge(label: label, accent: c, showDot: false),
            const SizedBox(width: 12),
            Text(
              date,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Routes tab ────────────────────────────────────────────────────────────────

  Widget _buildRoutesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Live Routes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
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
                eyebrow: 'OPERATIONS',
                title: 'Active Service Routes',
                subtitle: 'Real-time tracking of worker locations and route progress',
                badgeLabel: 'Live',
                showDot: true,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'View Live Worker Map',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const OmWorkerMapScreen())),
                accent: AppColors.manager,
                icon: Icons.map_outlined,
              ),
              const SizedBox(height: 20),
              if (_runs.isNotEmpty) ...[
                const _DarkSectionLabel(text: "TONIGHT'S ACTIVE RUNS"),
                const SizedBox(height: 8),
                ..._runs.map((run) => _buildRunCard(run)),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.route_outlined,
                            size: 48, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'No active routes',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> row) {
    final name = _workerName(row);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.worker.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: TextStyle(
                color: AppColors.worker,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Driver',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GlowBadge(
            label: 'Active',
            accent: AppColors.worker,
            showDot: true,
          ),
        ],
      ),
    );
  }

  // ── Reports tab ───────────────────────────────────────────────────────────────

  Widget _buildReportsTab() {
    final totalComebacks =
        _pendingComebacks + _acceptedComebacks + _completedComebacks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Reports & Metrics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              GlowBadge(
                label: '$totalComebacks comebacks',
                accent: totalComebacks > 0 ? AppColors.warning : AppColors.textMuted,
                showDot: _pendingComebacks > 0,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              RoleHeroCard(
                accent: AppColors.manager,
                eyebrow: 'PERFORMANCE',
                title: "Today's Service Metrics",
                subtitle: 'Track comebacks, completion rates, and route efficiency',
                badgeLabel: 'Ops Manager',
                showDot: false,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  StatTile(
                    value: '$_pendingComebacks',
                    label: 'Pending',
                    valueColor: _pendingComebacks > 0 ? AppColors.warning : null,
                  ),
                  const SizedBox(width: 8),
                  StatTile(value: '$_acceptedComebacks', label: 'In Progress'),
                  const SizedBox(width: 8),
                  StatTile(value: '$_completedComebacks', label: 'Completed',
                      valueColor: _completedComebacks > 0 ? AppColors.success : null),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'View Full Report',
                onPressed: () => Navigator.push(
                  context,
                  SharedAxisPageRoute(
                    builder: (_) => const TodayComebacksScreen(),
                  ),
                ),
                accent: AppColors.manager,
                icon: Icons.assessment_outlined,
              ),
              if (_comebackHistory.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _DarkSectionLabel(text: '7-DAY HISTORY'),
                const SizedBox(height: 10),
                ..._comebackHistory.take(5).map((h) => _buildHistoryCard(h)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Alerts tab ────────────────────────────────────────────────────────────────

  Widget _buildAlertsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Resident Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
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
                title: 'Send Alerts',
                subtitle:
                    'Notify residents about service updates, changes, or emergencies',
                badgeLabel: 'Ops Manager',
                showDot: false,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Alert All Residents',
                onPressed: () => Navigator.push(
                  context,
                  SharedAxisPageRoute(
                    builder: (_) => const SimpleNotificationSenderScreen(
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
                  SharedAxisPageRoute(
                    builder: (_) => const SimpleNotificationSenderScreen(
                        initialMode: 'user'),
                  ),
                ),
                icon: const Icon(Icons.person_outline, size: 18),
                label: const Text('Alert Specific Resident'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_sentNotifications.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _DarkSectionLabel(text: 'RECENT ALERTS'),
                const SizedBox(height: 10),
                ..._sentNotifications.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                n['title']?.toString() ?? 'Alert',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _formatDate(n['created_at'] as String?),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── More tab ──────────────────────────────────────────────────────────────────

  Widget _buildMoreTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        // Account card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.manager.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.manager, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operations Manager',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GlowBadge(label: 'OM', accent: AppColors.manager, showDot: false),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const _DarkSectionLabel(text: 'ACCOUNT'),
        const SizedBox(height: 12),

        // Properties stat
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.apartment_outlined,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 12),
              const Text(
                'Assigned Properties',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${_propertyIds.length}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_outline,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 12),
              const Text(
                'Workers Managed',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${_workers.length}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        const _DarkSectionLabel(text: 'SESSION'),
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

        // Sign out button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DarkSectionLabel extends StatelessWidget {
  final String text;
  const _DarkSectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}
