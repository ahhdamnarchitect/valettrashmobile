import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../auth/screens/change_password_screen.dart';
import 'resident_vacation_hold_screen.dart';

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
  String _windowShort = '--';
  int _freeRemain = 0;
  String _freeSummary = '--';

  List<Map<String, dynamic>> _notifications = [];
  bool _notifLoading = false;
  bool _notifLoaded = false;

  // Pickup status
  String? _runStatus; // 'pending', 'in_progress', 'completed'
  String? _propertyId;
  Timer? _statusTimer;

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

        final startT = prop['service_window_start'];
        final endT = prop['service_window_end'];
        _windowShort = '${_fmtTime(startT)} – ${_fmtTime(endT)}';
      }

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
                  icon: Icons.delete_outline,
                  activeIcon: Icons.delete,
                  label: 'Services',
                ),
                RoleNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'Messages',
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
        return _buildServicesTab();
      case 2:
        return _buildMessagesTab();
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
          SizedBox(height: 16),
          SkeletonCard(height: 88),
          SizedBox(height: 12),
          SkeletonCard(height: 88),
          SizedBox(height: 12),
          SkeletonCard(height: 110),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.rlvBlue,
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
          _buildDashboardHeader(),
          const SizedBox(height: 20),
          _buildSectionLabel('Upcoming Service'),
          const SizedBox(height: 8),
          _buildUpcomingServiceCard(),
          const SizedBox(height: 16),
          _buildSectionLabel('Service Status'),
          const SizedBox(height: 8),
          _buildServiceStatusCard(),
          const SizedBox(height: 16),
          _buildSectionLabel('Service Updates'),
          const SizedBox(height: 8),
          _buildServiceUpdatesCard(),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _propertyName.isEmpty ? 'Your Property' : _propertyName,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_propertyName.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _onTabChange(2),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: AppColors.textPrimary,
                size: 24,
              ),
              if (_notifications.isNotEmpty)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.rlvBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildUpcomingServiceCard() {
    final isOnSchedule = _runStatus == null || _runStatus == 'pending';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.rlvBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.delete_outline,
              color: AppColors.rlvBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tonight',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _windowShort == '--'
                      ? 'No window configured'
                      : _windowShort,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isOnSchedule ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isOnSchedule
                        ? AppColors.success
                        : AppColors.warning)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isOnSchedule ? 'On Schedule' : 'In Progress',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    isOnSchedule ? AppColors.success : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    final isCompleted = _runStatus == 'completed';
    final isInProgress = _runStatus == 'in_progress';
    final color = isCompleted
        ? AppColors.success
        : isInProgress
            ? AppColors.warning
            : AppColors.success;
    final icon = isCompleted
        ? Icons.check_circle_outline
        : isInProgress
            ? Icons.local_shipping_outlined
            : Icons.check_circle_outline;
    final statusText = isCompleted
        ? 'Pickup Complete'
        : isInProgress
            ? 'Porter En Route'
            : 'All Clear';
    final subText = isCompleted
        ? 'Collected tonight'
        : isInProgress
            ? 'Your porter is collecting now'
            : 'No missed collections';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildServiceUpdatesCard() {
    if (_notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'No updates at this time.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    final items = _notifications.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final n = items[i];
          final isLast = i == items.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () => _onTabChange(2),
                borderRadius: i == 0
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : isLast
                        ? const BorderRadius.vertical(
                            bottom: Radius.circular(12))
                        : BorderRadius.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['message']?.toString() ??
                                  n['title']?.toString() ??
                                  '',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (n['created_at'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatNotifDate(
                                    n['created_at'].toString()),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, color: AppColors.border),
            ],
          );
        }),
      ),
    );
  }

  String _formatNotifDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ── Services ─────────────────────────────────────────────────────────────────

  Widget _buildServicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Services'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: const [ResidentPickupHistoryView()],
          ),
        ),
      ],
    );
  }

  // ── Messages ─────────────────────────────────────────────────────────────────

  Widget _buildMessagesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Messages'),
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
