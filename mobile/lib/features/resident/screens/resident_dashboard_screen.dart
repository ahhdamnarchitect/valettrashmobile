import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../auth/screens/change_password_screen.dart';
import '../models/comeback_pricing.dart';
import '../widgets/buy_extra_pickups_section.dart';
import '../widgets/extra_services_grid.dart';
import 'resident_comeback_request_screen.dart';
import 'resident_concerns_screen.dart';
import 'resident_notifications_screen.dart';
import 'resident_report_missed_pickup_screen.dart';
import 'resident_violations_screen.dart';
import 'resident_vacation_hold_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _tabIndex = 0;
  /// 0 = request a service, 1 = buy comeback packs (Extra Services tab only).
  int _extraServicesSegment = 0;
  bool _loading = true;
  String? _loadError;

  String _residentName = 'Resident';
  String _email = '';
  String _propertyName = '';
  String _windowShort = '--';
  int _freeRemain = 0;
  int _purchasedBalance = 0;
  String _freeSummary = '--';
  String? _residentUnitId;

  bool _workerClockedIn = false;
  String? _propertyId;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  dynamic _windowStartRaw;
  String _countdownLabel = '--';
  int _violationCount = 0;
  String _violationLabel = 'None';

  // Satisfaction
  int _completedRatingCount = 0;
  bool _satisfactionCardDismissed = false;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _load();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _propertyId != null) _pollWorkerClockStatus();
    });
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (_windowStartRaw == null) return;
    final parts = _windowStartRaw.toString().split(':');
    if (parts.length < 2) return;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, h, m);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final diff = target.difference(now);
    final hours = diff.inHours;
    final label = diff.inMinutes <= 0
        ? 'Now'
        : hours < 1
            ? '<1h'
            : '${hours}h';
    if (_countdownLabel != label && mounted) {
      setState(() => _countdownLabel = label);
    }
  }

  String get _pickupActionSubtitle {
    if (_freeRemain > 0) {
      return 'Free — monthly comeback ($_freeRemain left)';
    }
    if (_purchasedBalance > 0) {
      return 'Free — banked comeback ($_purchasedBalance left)';
    }
    return 'Paid — \$5 per comeback (packs on Extra Services)';
  }

  String get _nextPickupDateLabel {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String get _workerStatusLabel =>
      _workerClockedIn ? 'ON DUTY' : 'SCHEDULED';

  Color get _workerStatusColor =>
      _workerClockedIn ? AppColors.success : AppColors.rlvBlue;

  Future<void> _pollWorkerClockStatus() async {
    if (_propertyId == null) return;
    try {
      final row = await Supabase.instance.client
          .from('clock_events')
          .select('event_type')
          .eq('property_id', _propertyId!)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final onDuty =
          row != null && row['event_type']?.toString() == 'clock_in';
      if (onDuty != _workerClockedIn && mounted) {
        setState(() => _workerClockedIn = onDuty);
      }
    } catch (_) {}
  }

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
              id,
              property_id,
              purchased_comeback_balance,
              properties (
                name,
                service_window_start,
                service_window_end
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
        _residentUnitId = assignmentMap['id']?.toString();
        _purchasedBalance =
            assignmentMap['purchased_comeback_balance'] as int? ?? 0;

        final now = DateTime.now();
        final monthStart =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
        final pid = assignmentMap['property_id']?.toString();

        Map<String, dynamic>? usage;
        if (pid != null) {
          usage = await Supabase.instance.client
              .from('resident_monthly_usage')
              .select('free_comeback_used')
              .eq('resident_user_id', uid)
              .eq('property_id', pid)
              .eq('month', monthStart)
              .maybeSingle();
        }

        final usedFree =
            usage == null ? 0 : (usage['free_comeback_used'] as int? ?? 0);
        _freeRemain = (kMonthlyFreeComebacks - usedFree)
            .clamp(0, kMonthlyFreeComebacks);
        _freeSummary = _freeRemain > 0
            ? '$_freeRemain free this month (resets monthly)'
            : 'Free comeback used this month';
        if (_purchasedBalance > 0) {
          _freeSummary += ' · $_purchasedBalance banked';
        }

        final startT =
            prop['service_window_start'] ?? kDefaultServiceWindowStart;
        final endT = prop['service_window_end'] ?? kDefaultServiceWindowEnd;
        _windowStartRaw = startT;
        _windowShort = '${_fmtTime(startT)} – ${_fmtTime(endT)}';
        _updateCountdown();
      }

      try {
        final violations = await Supabase.instance.client
            .from('violations')
            .select('id')
            .eq('resident_user_id', uid)
            .neq('status', 'resolved');
        _violationCount = (violations as List).length;
        _violationLabel = _violationCount == 0
            ? 'None'
            : _violationCount == 1
                ? 'Warning'
                : '$_violationCount active';
      } catch (_) {}

      // Load satisfaction count
      try {
        final ratings = await Supabase.instance.client
            .from('satisfaction_ratings')
            .select('id')
            .eq('user_id', uid);
        _completedRatingCount = (ratings as List).length;
      } catch (_) {}

      if (mounted) setState(() => _loading = false);
      if (_propertyId != null) _pollWorkerClockStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _onTabChange(int index) {
    setState(() => _tabIndex = index);
  }

  void _openExtraServices({int segment = 0}) {
    setState(() {
      _tabIndex = 1;
      _extraServicesSegment = segment;
    });
  }

  Future<void> _signOut(BuildContext ctx) async {
    await Supabase.instance.client.auth.signOut();
    if (!ctx.mounted) return;
    Navigator.of(ctx).popUntil((route) => route.isFirst);
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
              accent: AppColors.rlvBlue,
              items: const [
                RoleNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                ),
                RoleNavItem(
                  icon: Icons.grid_view_outlined,
                  activeIcon: Icons.grid_view,
                  label: 'Extra Services',
                ),
                RoleNavItem(
                  icon: Icons.support_agent_outlined,
                  activeIcon: Icons.support_agent,
                  label: 'Support',
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
    // Only mount the active tab so hidden grids cannot steal taps (IndexedStack issue on web).
    switch (_tabIndex) {
      case 1:
        return _buildExtraServicesTab();
      case 2:
        return _buildSupportTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildHomeTab();
    }
  }

  // ── Home Tab ──────────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: const [
          SkeletonCard(height: 52),
          SizedBox(height: 16),
          SkeletonCard(height: 140),
          SizedBox(height: 12),
          SkeletonCard(height: 80),
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
          if (_loadError != null) ...[
            GlowBadge(
              label: _loadError!,
              accent: AppColors.error,
              showDot: false,
            ),
            const SizedBox(height: 12),
          ],
          _buildMockHeader(),
          const SizedBox(height: 16),
          _buildNextPickupCard(),
          const SizedBox(height: 12),
          _buildStatTilesRow(),
          const SizedBox(height: 12),
          _buildQuickActionsCard(),
          const SizedBox(height: 20),
          _buildAvailableServicesSection(),
          const SizedBox(height: 12),
          _buildSupportBar(),
          const SizedBox(height: 8),
          _buildSatisfactionCard(),
        ],
      ),
    );
  }

  Widget _buildMockHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.rlvBlue.withValues(alpha: 0.15),
          child: Text(
            _residentName.isNotEmpty
                ? _residentName[0].toUpperCase()
                : 'R',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              color: AppColors.rlvBlue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome!',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              Text(
                _residentName.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Worker Status',
              style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _workerStatusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _workerStatusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _workerStatusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResidentNotificationsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.notifications_outlined,
                color: AppColors.rlvBlue, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _buildNextPickupCard() {
    return BentoCard(
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              color: AppColors.rlvBlue, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nextPickupDateLabel,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _windowShort == '--'
                      ? 'Service window not set'
                      : 'Service: $_windowShort',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Next Pickup',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                _countdownLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTilesRow() {
    return Row(
      children: [
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FREE COMEBACKS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_freeRemain',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _freeSummary,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          // The tile showed a violation count with no way to see the violations
          // themselves - ResidentViolationsScreen existed but nothing opened it.
          child: BentoCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResidentViolationsScreen()),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIOLATIONS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_violationCount',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _violationLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard() {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _quickActionTile(
            icon: Icons.event_outlined,
            title: 'Request Pickup',
            subtitle: _pickupActionSubtitle,
            onTap: () async {
              final refreshed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ResidentComebackRequestScreen(
                    freeRemain: _freeRemain,
                    purchasedBalance: _purchasedBalance,
                    propertyId: _propertyId,
                    residentUnitId: _residentUnitId,
                  ),
                ),
              );
              if (refreshed == true && mounted) _load();
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          _quickActionTile(
            icon: Icons.history,
            title: 'Service History',
            subtitle: 'View past pickups',
            onTap: () => _openExtraServices(segment: 0),
          ),
          const Divider(height: 1, color: AppColors.border),
          // ResidentReportMissedPickupScreen was fully built but nothing imported it,
          // so residents had no way to report a missed pickup - the trigger for the
          // whole comeback loop.
          _quickActionTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Report a Missed Pickup',
            subtitle: 'Tell us if we missed your door',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ResidentReportMissedPickupScreen()),
              );
              if (mounted) _load();
            },
          ),
          const Divider(height: 1, color: AppColors.border),
          _quickActionTile(
            icon: Icons.shopping_cart_outlined,
            title: 'Buy Extra Pickups',
            subtitle: '1/\$5 · 3/\$14 · 5/\$20',
            onTap: () => _openExtraServices(segment: 1),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.success, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableServicesSection() {
    return BentoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openExtraServices(segment: 0),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.grid_view_outlined,
                  color: AppColors.success, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extra Services & Pickups',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Moving, maid, bulk trash · buy comeback packs',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportBar() {
    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.headset_mic_outlined,
              color: AppColors.rlvBlue, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Questions or Concerns? We're here to help",
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _tabIndex = 2),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Message',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSatisfactionCard() {
    final shouldShowModal =
        _completedRatingCount > 0 && _completedRatingCount % 5 == 0;
    final shouldShowCard = !_satisfactionCardDismissed && !shouldShowModal;

    if (shouldShowModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRatingModal();
      });
    }
    if (!shouldShowCard) return const SizedBox.shrink();

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.star_outline, color: AppColors.rlvBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How was your last service?',
                  style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                Text(
                  'Tap to rate',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showRatingModal,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text(
              'Rate',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rlvBlue),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _satisfactionCardDismissed = true),
            child: const Icon(Icons.close,
                size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingModal() async {
    int selectedRating = 0;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                'Rate Your Service',
                style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'How was your trash valet service?',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setModal(() => selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        i < selectedRating
                            ? Icons.star
                            : Icons.star_outline,
                        color: AppColors.rlvBlue,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedRating == 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _submitRating(selectedRating);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.rlvBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.rlvBlue.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Submit',
                    style: GoogleFonts.montserrat(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(int rating) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || _propertyId == null) return;
    try {
      await Supabase.instance.client.from('satisfaction_ratings').insert({
        'user_id': uid,
        'property_id': _propertyId,
        'rating': rating,
      });
      if (mounted) setState(() => _completedRatingCount++);
    } catch (_) {}
  }

  // ── Extra Services Tab ────────────────────────────────────────────────────────

  Widget _buildExtraServicesSegmentButton(String label, int index) {
    final selected = _extraServicesSegment == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _extraServicesSegment = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.rlvBlue : AppColors.surface1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.rlvBlue : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraServicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Extra Services'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              _buildExtraServicesSegmentButton('Request Service', 0),
              const SizedBox(width: 8),
              _buildExtraServicesSegmentButton('Buy Comebacks', 1),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              if (_extraServicesSegment == 0) ...[
                Text(
                  'Tap a service to submit a request with date and time.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ExtraServicesGrid(propertyId: _propertyId),
              ] else ...[
                BuyExtraPickupsSection(onPurchased: _load),
              ],
              const SizedBox(height: 24),
              Text(
                'SERVICE HISTORY',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const ResidentPickupHistoryView(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Support Tab ───────────────────────────────────────────────────────────────

  Widget _buildSupportTab() {
    return const ResidentSupportPanel();
  }

  // ── Profile Tab ──────────────────────────────────────────────────────────────

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
              BentoCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppColors.rlvBlue.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: GoogleFonts.montserrat(
                            color: AppColors.rlvBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _residentName,
                            style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _email,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: 'Resident',
                      accent: AppColors.rlvBlue,
                    ),
                  ],
                ),
              ),
              if (_propertyName.isNotEmpty) ...[
                const SizedBox(height: 12),
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROPERTY',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _propertyName,
                        style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Service window: $_windowShort',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _freeSummary,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              BentoCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ResidentVacationHoldScreen()),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.beach_access_outlined,
                          color: Color(0xFFFF9F0A), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vacation Hold',
                            style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            'Pause pickups while away',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Change Password',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen()),
                ),
                accent: AppColors.rlvBlue,
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Pickup History ────────────────────────────────────────────────────────────

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
            ],
          );
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_outlined,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No pickup history yet',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          children: list.map((row) {
            final u = row['units'];
            final unit = (u is Map && u['unit_number'] != null)
                ? '${u['unit_number']}'
                : '?';
            final when = row['completed_at'] ?? row['created_at'] ?? '';
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
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _prettyStatus(status).toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Unit $unit · $when',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary),
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
