import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/role_hero_card.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../auth/screens/change_password_screen.dart';
import 'resident_comeback_request_screen.dart';
import 'resident_concerns_screen.dart';
import 'resident_vacation_hold_screen.dart';
import 'resident_violations_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  String? _loadError;

  String _residentName = 'Resident';
  String _email = '';
  String _propertyName = '';
  String _serviceDateStr = '--';
  String _windowShort = '--';
  String _countdownLabel = '—';
  int _freeRemain = 0;
  String _freeSummary = '--';
  int _violationsCount = 0;
  num _comebackFee = 15;

  List<Map<String, dynamic>> _notifications = [];
  bool _notifLoading = false;
  bool _notifLoaded = false;

  // Pickup status banner
  String? _runStatus; // 'pending', 'in_progress', 'completed'
  String? _propertyId;
  Timer? _statusTimer;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _load();
    // Poll pickup status every 30 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _propertyId != null) _pollRunStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollRunStatus() async {
    if (_propertyId == null) return;
    try {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final row = await Supabase.instance.client
          .from('nightly_runs')
          .select('status')
          .eq('property_id', _propertyId!)
          .eq('run_date', todayStr)
          .maybeSingle();
      if (row == null) return;
      final newStatus = row['status']?.toString();
      if (newStatus != null && newStatus != _runStatus) {
        if (mounted) setState(() {
          _runStatus = newStatus;
          _bannerDismissed = false;
        });
      }
    } catch (_) {}
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  String _fmtTime(dynamic pgTime) {
    if (pgTime == null) return '--';
    final parts = pgTime.toString().split(':');
    if (parts.length < 2) return pgTime.toString();
    final hRaw = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final ap = hRaw >= 12 ? 'PM' : 'AM';
    var h12 = hRaw % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $ap';
  }

  String _nextWindowPhrase(
      DateTime todayLocal, dynamic startStr, dynamic endStr) {
    final startLbl = _fmtTime(startStr);
    final endLbl = _fmtTime(endStr);
    final partsStart = startStr.toString().split(':');
    if (partsStart.length < 2) return 'Window $startLbl – $endLbl';
    final sh = int.tryParse(partsStart[0]) ?? 18;
    final sm = int.tryParse(partsStart[1]) ?? 0;
    final start =
        DateTime(todayLocal.year, todayLocal.month, todayLocal.day, sh, sm);
    if (todayLocal.isBefore(start)) {
      final mins = start.difference(todayLocal).inMinutes;
      if (mins < 60) return 'Starts in ${mins}m';
      final h = mins ~/ 60;
      final m = mins % 60;
      return 'Starts in ${h}h ${m}m';
    }
    final partsEnd = endStr.toString().split(':');
    if (partsEnd.length < 2) return 'In service until $endLbl';
    final eh = int.tryParse(partsEnd[0]) ?? 22;
    final em = int.tryParse(partsEnd[1]) ?? 0;
    final end =
        DateTime(todayLocal.year, todayLocal.month, todayLocal.day, eh, em);
    if (todayLocal.isBefore(end)) return 'In service until ${_fmtTime(endStr)}';
    return 'Next window tomorrow $startLbl – $endLbl';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final assignment = await Supabase.instance.client
          .from('resident_units')
          .select('''
              property_id,
              properties (
                name,
                service_window_start,
                service_window_end,
                free_comeback_pickups_per_month,
                comeback_pickup_fee
              )
            ''')
          .eq('user_id', uid)
          .eq('is_active', true)
          .maybeSingle();

      final profile = await Supabase.instance.client
          .from('users')
          .select('first_name,last_name')
          .eq('id', uid)
          .maybeSingle();

      if (mounted && profile != null) {
        final fn = '${profile['first_name'] ?? ''}'.trim();
        final ln = '${profile['last_name'] ?? ''}'.trim();
        if (fn.isNotEmpty || ln.isNotEmpty) {
          _residentName = ('$fn $ln').trim();
        }
      }

      Map<String, dynamic>? prop;
      Map<String, dynamic>? assignmentMap;
      if (assignment != null) {
        assignmentMap = Map<String, dynamic>.from(assignment as Map);
        final propsRaw = assignmentMap['properties'];
        if (propsRaw is Map) prop = Map<String, dynamic>.from(propsRaw);
      }

      if (prop != null && assignmentMap != null) {
        _propertyName = prop['name']?.toString() ?? '';
        _propertyId = assignmentMap['property_id']?.toString();
        _comebackFee = prop['comeback_pickup_fee'] is num
            ? prop['comeback_pickup_fee'] as num
            : 15;
        final freeCapRaw = prop['free_comeback_pickups_per_month'];
        final freeCap =
            freeCapRaw is int ? freeCapRaw : int.tryParse('$freeCapRaw') ?? 0;
        final now = DateTime.now();
        final monthStart =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        final pid = assignmentMap['property_id']?.toString();

        Map<String, dynamic>? usage;
        if (pid != null) {
          usage = await Supabase.instance.client
              .from('resident_monthly_usage')
              .select('free_comeback_used, paid_comeback_used')
              .eq('resident_user_id', uid)
              .eq('property_id', pid)
              .eq('month', monthStart)
              .maybeSingle();
        }

        final usedFree =
            usage == null ? 0 : (usage['free_comeback_used'] as int? ?? 0);
        final remain = freeCap - usedFree;
        _freeRemain =
            remain < 0 ? 0 : (remain > freeCap ? freeCap : remain);
        _freeSummary = freeCap <= 0
            ? 'No free comebacks configured'
            : '$_freeRemain of $freeCap left this month';

        _serviceDateStr = '${now.month}/${now.day}/${now.year}';
        final startT = prop['service_window_start'];
        final endT = prop['service_window_end'];
        _windowShort = '${_fmtTime(startT)} – ${_fmtTime(endT)}';
        _countdownLabel = _nextWindowPhrase(now, startT, endT);
      }

      final viol = await Supabase.instance.client
          .from('violations')
          .select('id')
          .eq('resident_user_id', uid);
      _violationsCount = viol is List ? viol.length : 0;

      setState(() => _loading = false);

      // Pre-load notifications for the preview card
      if (!_notifLoaded) _loadNotifications();
      // Initial pickup status check
      if (_propertyId != null) _pollRunStatus();
    } catch (e) {
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadNotifications() async {
    if (_notifLoading) return;
    setState(() => _notifLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(50);
      _notifications = List<Map<String, dynamic>>.from(rows as List);
      _notifLoaded = true;
    } catch (_) {}
    if (mounted) setState(() => _notifLoading = false);
  }

  Future<void> _signOut(BuildContext ctx) async {
    await Supabase.instance.client.auth.signOut();
    if (!ctx.mounted) return;
    Navigator.of(ctx).popUntil((route) => route.isFirst);
  }

  void _onTabChange(int index) {
    setState(() => _tabIndex = index);
    if (index == 2 && !_notifLoaded) _loadNotifications();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface1,
      content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
              onTap: _onTabChange,
              accent: AppColors.resident,
              items: const [
                RoleNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                ),
                RoleNavItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'History',
                ),
                RoleNavItem(
                  icon: Icons.notifications_outlined,
                  activeIcon: Icons.notifications,
                  label: 'Alerts',
                ),
                RoleNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
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
        return _buildHomeTab();
      case 1:
        return _buildHistoryTab();
      case 2:
        return _buildAlertsTab();
      default:
        return _buildProfileTab();
    }
  }

  // ── Home ─────────────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: const [
          SkeletonCard(height: 52),
          SizedBox(height: 20),
          SkeletonCard(height: 128),
          SizedBox(height: 12),
          SkeletonCard(height: 60),
          SizedBox(height: 16),
          SkeletonCard(height: 110),
          SizedBox(height: 16),
          SkeletonCard(height: 70),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.resident,
      backgroundColor: AppColors.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: [
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlowBadge(
                label: _loadError!,
                accent: AppColors.error,
                showDot: false,
              ),
            ),
          if (!_bannerDismissed && _runStatus != null &&
              _runStatus != 'pending')
            _buildPickupStatusBanner(),
          _buildGreeting(),
          const SizedBox(height: 20),
          RoleHeroCard(
            accent: AppColors.resident,
            eyebrow: "TONIGHT'S SERVICE",
            title: _propertyName.isEmpty
                ? 'No Property Assigned'
                : _propertyName,
            subtitle: 'Window: $_windowShort',
            badgeLabel: _countdownLabel,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(value: '$_freeRemain', label: 'Comebacks Left'),
              const SizedBox(width: 8),
              StatTile(
                value: '$_violationsCount',
                label: 'Violations',
                valueColor:
                    _violationsCount > 0 ? AppColors.error : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionsCard(),
          if (_notifications.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotifPreview(_notifications.first),
          ],
        ],
      ),
    );
  }

  Widget _buildPickupStatusBanner() {
    final isInProgress = _runStatus == 'in_progress';
    final color = isInProgress ? AppColors.warning : AppColors.success;
    final icon = isInProgress ? Icons.local_shipping_outlined : Icons.check_circle_outline;
    final message = isInProgress
        ? 'Your porter is collecting now'
        : 'Pickup complete for tonight';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _bannerDismissed = true),
              child: const Icon(Icons.close,
                  color: AppColors.textMuted, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final initial =
        _residentName.isNotEmpty ? _residentName[0].toUpperCase() : 'R';
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.resident.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(
              color: AppColors.resident,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good evening,',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _residentName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _actionRow(
            icon: Icons.replay_outlined,
            iconColor: AppColors.resident,
            title: 'Request a Comeback',
            subtitle: _freeRemain > 0
                ? '$_freeRemain free remaining this month'
                : 'Additional comebacks — \$${_comebackFee.toStringAsFixed(0)}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResidentComebackRequestScreen(
                  freeRemain: _freeRemain,
                  comebackFee: _comebackFee,
                ),
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          _actionRow(
            icon: Icons.help_outline,
            iconColor: AppColors.info,
            title: 'Questions & Concerns',
            subtitle: 'Submit a question or feedback',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResidentConcernsScreen(),
              ),
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          _actionRow(
            icon: Icons.history_outlined,
            iconColor: AppColors.textSecondary,
            title: 'Service History',
            subtitle: 'View past pickups',
            onTap: () => _onTabChange(1),
          ),
          Divider(height: 1, color: AppColors.border),
          _actionRow(
            icon: Icons.warning_amber_outlined,
            iconColor:
                _violationsCount > 0 ? AppColors.error : AppColors.textMuted,
            title: 'Violations',
            subtitle: _violationsCount == 0
                ? 'None on record'
                : '$_violationsCount on record',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ResidentViolationsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifPreview(Map<String, dynamic> n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.notifications_outlined, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n['title']?.toString() ?? 'Notification',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  n['message']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onTabChange(2),
            child: Text(
              'See all',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.resident,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── History ──────────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Service History'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: const [ResidentPickupHistoryView()],
          ),
        ),
      ],
    );
  }

  // ── Alerts ───────────────────────────────────────────────────────────────────

  Widget _buildAlertsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Notifications'),
        if (_notifLoading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                SkeletonCard(height: 72),
                SizedBox(height: 10),
                SkeletonCard(height: 72),
                SizedBox(height: 10),
                SkeletonCard(height: 72),
                SizedBox(height: 10),
                SkeletonCard(height: 72),
              ],
            ),
          )
        else if (_notifications.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: AppColors.resident,
              backgroundColor: AppColors.surface1,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _buildNotifCard(_notifications[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> n) {
    final typeColor = _notifTypeColor(n['type']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _notifTypeIcon(n['type']?.toString() ?? ''),
              size: 18,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n['title']?.toString() ?? 'Notification',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  n['message']?.toString() ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _notifTypeColor(String type) {
    switch (type) {
      case 'violation':
        return AppColors.error;
      case 'pickup_scheduled':
      case 'pickup_completed':
        return AppColors.success;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  IconData _notifTypeIcon(String type) {
    switch (type) {
      case 'violation':
        return Icons.warning_amber_outlined;
      case 'pickup_scheduled':
        return Icons.schedule_outlined;
      case 'pickup_completed':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final initial =
        _residentName.isNotEmpty ? _residentName[0].toUpperCase() : 'R';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Profile'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.resident.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.resident,
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
                            _residentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: 'Resident',
                      accent: AppColors.resident,
                    ),
                  ],
                ),
              ),
              if (_propertyName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROPERTY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _propertyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Service window: $_windowShort',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _freeSummary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.beach_access_outlined,
                        color: AppColors.warning, size: 20),
                  ),
                  title: const Text('Vacation Hold',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text('Pause pickups while away',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted, size: 20),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const ResidentVacationHoldScreen())),
                ),
              ),
              const SizedBox(height: 24),
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
                onPressed: () => _signOut(context),
                accent: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ── Pickup history widget (preserved) ────────────────────────────────────────

class ResidentPickupHistoryView extends StatelessWidget {
  const ResidentPickupHistoryView({super.key});

  Future<List<Map<String, dynamic>>> _fetchPickups() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await Supabase.instance.client
        .from('pickups')
        .select('status, completed_at, created_at, units ( unit_number )')
        .eq('resident_user_id', uid)
        .order('created_at', ascending: false)
        .limit(25);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  String _prettyStatus(String? s) {
    if (s == null) return 'Unknown';
    return s.replaceAll('_', ' ');
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed':
        return AppColors.success;
      case 'missed':
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPickups(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Column(
            children: [
              SkeletonCard(height: 66),
              SizedBox(height: 10),
              SkeletonCard(height: 66),
              SizedBox(height: 10),
              SkeletonCard(height: 66),
              SizedBox(height: 10),
              SkeletonCard(height: 66),
              SizedBox(height: 10),
              SkeletonCard(height: 66),
              SizedBox(height: 10),
              SkeletonCard(height: 66),
            ],
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_outlined,
                      size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No pickup history yet',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: list.asMap().entries.map((entry) {
            final row = entry.value;
            final u = row['units'];
            final unit = (u is Map && u['unit_number'] != null)
                ? '${u['unit_number']}'
                : '?';
            final when =
                row['completed_at'] ?? row['created_at'] ?? '';
            final status = row['status'] as String?;
            final color = _statusColor(status);
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _prettyStatus(status).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Unit $unit · $when',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Legacy helper classes (kept for compatibility) ────────────────────────────

class SimplePage extends StatelessWidget {
  final String title;
  final Widget child;

  const SimplePage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}
