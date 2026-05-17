import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import 'violation_report_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_route_map_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  String _email = '';
  bool _isOnDuty = false;
  String _assignedProperty = 'No property assigned';
  String _assignedRoute = 'No active route';
  List<Map<String, dynamic>> _comebackRequests = [];
  String? _propertyId;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _loadRouteData();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadRouteData() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    setState(() => _loading = true);
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final assigns = await client
          .from('worker_assignments')
          .select('property_id, properties(name)')
          .eq('user_id', user.id)
          .eq('is_active', true);
      final assignList = List<Map<String, dynamic>>.from(assigns as List);
      final names = <String>[];
      final propertyIds = <String>{};
      for (final row in assignList) {
        final p = row['properties'];
        if (p is Map && p['name'] != null) names.add('${p['name']}');
        final pid = row['property_id']?.toString();
        if (pid != null) propertyIds.add(pid);
      }
      if (names.isNotEmpty) _assignedProperty = names.join(', ');
      if (propertyIds.isNotEmpty) _propertyId = propertyIds.first;

      final routes = await client
          .from('routes')
          .select('id, name')
          .eq('worker_id', user.id)
          .eq('is_active', true);
      final routeList = List<Map<String, dynamic>>.from(routes as List);
      if (routeList.isNotEmpty) {
        final routeId = routeList.first['id'];
        final stops = await client
            .from('route_stops')
            .select('stop_order, units(unit_number)')
            .eq('route_id', routeId)
            .order('stop_order', ascending: true);
        final stopList = List<Map<String, dynamic>>.from(stops as List);
        final nums = stopList
            .map((s) {
              final u = s['units'];
              return u is Map ? u['unit_number']?.toString() : null;
            })
            .whereType<String>()
            .toList();
        _assignedRoute =
            '${routeList.first['name']}: ${nums.take(20).join(', ')}${nums.length > 20 ? '…' : ''}';
      }

      final rawComebacks = await client
          .from('missed_pickup_requests')
          .select(
              'id, status, requested_at, pickups(units(unit_number), nightly_runs(property_id))')
          .limit(80);
      final cbList = List<Map<String, dynamic>>.from(rawComebacks as List);
      _comebackRequests = [];
      for (final row in cbList) {
        final p = row['pickups'];
        if (p is! Map) continue;
        final nr = p['nightly_runs'];
        final propId = nr is Map ? nr['property_id']?.toString() : null;
        if (propId != null && !propertyIds.contains(propId)) continue;
        final u = p['units'];
        final unit = u is Map ? u['unit_number']?.toString() ?? '?' : '?';
        _comebackRequests.add({
          'id': row['id']?.toString(),
          'unit': unit,
          'type': 'Comeback',
          'time': row['requested_at']?.toString() ?? '',
          'status': row['status']?.toString() ?? 'pending',
        });
      }

      // Restore clock-in state from last clock event
      try {
        final lastEvent = await client
            .from('clock_events')
            .select('event_type')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (lastEvent != null && lastEvent['event_type'] == 'clock_in') {
          _isOnDuty = true;
        }
      } catch (_) {}
    } catch (_) {
      _comebackRequests = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeComebackRequest(int index) async {
    final item = _comebackRequests[index];
    final id = item['id']?.toString();
    if (id != null) {
      try {
        await Supabase.instance.client
            .from('missed_pickup_requests')
            .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', id);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _comebackRequests.removeAt(index));
      _snack('Comeback completed');
    }
  }

  // Shows a bottom sheet with optional photo before marking comeback complete
  Future<void> _showCompleteSheet(int index) async {
    Uint8List? photoBytes;
    String? photoName;
    bool uploading = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
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
                // Handle
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
                const Text(
                  'Mark Pickup Complete',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Optionally add a proof-of-pickup photo',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                // Photo area
                GestureDetector(
                  onTap: () async {
                    try {
                      final file = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1280,
                        imageQuality: 82,
                      );
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      setSheetState(() {
                        photoBytes = bytes;
                        photoName = file.name;
                      });
                    } catch (_) {}
                  },
                  child: Container(
                    height: photoBytes != null ? null : 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: photoBytes != null
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoBytes != null
                        ? Image.memory(photoBytes!, fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_outlined,
                                  color: AppColors.textMuted, size: 28),
                              SizedBox(height: 6),
                              Text(
                                'Add photo (optional)',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: uploading
                            ? null
                            : () async {
                                setSheetState(() => uploading = true);
                                // Upload photo if selected
                                if (photoBytes != null &&
                                    photoName != null) {
                                  try {
                                    final uid = Supabase
                                        .instance.client.auth.currentUser?.id;
                                    final ext =
                                        photoName!.split('.').last;
                                    final path =
                                        'pickup_proofs/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
                                    await Supabase.instance.client.storage
                                        .from('violations')
                                        .uploadBinary(path, photoBytes!);
                                  } catch (_) {}
                                }
                                Navigator.pop(ctx);
                                _completeComebackRequest(index);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          uploading ? 'Uploading…' : 'Mark Done',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _toggleDuty() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final newState = !_isOnDuty;
    setState(() => _isOnDuty = newState);
    try {
      await Supabase.instance.client.from('clock_events').insert({
        'user_id': uid,
        'event_type': newState ? 'clock_in' : 'clock_out',
        'property_id': _propertyId,
      });
    } catch (_) {
      // Non-blocking — UI state already updated
    }
    _snack(newState ? 'You are now on duty' : 'You are now off duty');
  }

  Future<void> _shareLocation() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final pos = await html.window.navigator.geolocation
          .getCurrentPosition()
          .timeout(const Duration(seconds: 10));
      final lat = pos.coords!.latitude!.toDouble();
      final lng = pos.coords!.longitude!.toDouble();
      await Supabase.instance.client.from('worker_locations').upsert({
        'user_id': uid,
        'property_id': _propertyId,
        'latitude': lat,
        'longitude': lng,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _snack('Location shared');
    } catch (e) {
      _snack('Could not get location: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface1,
      content: Text(msg, style: const TextStyle(color: AppColors.textPrimary)),
    ));
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
              accent: AppColors.worker,
              items: const [
                RoleNavItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: 'Route',
                ),
                RoleNavItem(
                  icon: Icons.replay_outlined,
                  activeIcon: Icons.replay,
                  label: 'Comebacks',
                ),
                RoleNavItem(
                  icon: Icons.warning_amber_outlined,
                  activeIcon: Icons.warning_amber,
                  label: 'Violations',
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
        return _buildRouteTab();
      case 1:
        return _buildComebacksTab();
      case 2:
        return _buildViolationsTab();
      default:
        return _buildProfileTab();
    }
  }

  // ── Route ─────────────────────────────────────────────────────────────────────

  Widget _buildRouteTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: const [
          SkeletonCard(height: 140),
          SizedBox(height: 12),
          SkeletonCard(height: 60),
          SizedBox(height: 16),
          SkeletonCard(height: 56),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRouteData,
      color: AppColors.worker,
      backgroundColor: AppColors.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: [
          RoleHeroCard(
            accent: AppColors.worker,
            eyebrow: "TONIGHT'S ROUTE",
            title: _assignedProperty,
            subtitle: _assignedRoute == 'No active route'
                ? 'No route assigned'
                : _assignedRoute.length > 60
                    ? '${_assignedRoute.substring(0, 60)}…'
                    : _assignedRoute,
            badgeLabel: _isOnDuty ? 'On Duty' : 'Off Duty',
            showDot: _isOnDuty,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatTile(
                value: '${_comebackRequests.length}',
                label: 'Comebacks',
                valueColor: _comebackRequests.isNotEmpty
                    ? AppColors.error
                    : null,
              ),
              const SizedBox(width: 8),
              StatTile(
                value: _isOnDuty ? 'Active' : 'Idle',
                label: 'Status',
                valueColor: _isOnDuty ? AppColors.worker : AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isOnDuty ? 'Clock Out' : 'Clock In',
            onPressed: _toggleDuty,
            accent: _isOnDuty ? AppColors.error : AppColors.worker,
            icon: _isOnDuty ? Icons.stop_circle_outlined : Icons.play_circle_outline,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              SharedAxisPageRoute(
                builder: (_) => WorkerRouteMapScreen(
                  propertyName: _assignedProperty,
                  comebacks: _comebackRequests,
                ),
              ),
            ),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('View Route Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isOnDuty ? _shareLocation : null,
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('Share My Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.worker,
              side: const BorderSide(color: AppColors.worker),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (!_isOnDuty) ...[
            const SizedBox(height: 12),
            const Text(
              'Clock in to begin your route for tonight.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Comebacks ─────────────────────────────────────────────────────────────────

  Widget _buildComebacksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Comebacks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_comebackRequests.isNotEmpty)
                GlowBadge(
                  label: '${_comebackRequests.length} pending',
                  accent: AppColors.warning,
                  showDot: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: const [
                SkeletonCard(height: 70),
                SizedBox(height: 10),
                SkeletonCard(height: 70),
                SizedBox(height: 10),
                SkeletonCard(height: 70),
              ],
            ),
          )
        else if (_comebackRequests.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: AppColors.success),
                  SizedBox(height: 12),
                  Text(
                    'No comeback requests',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRouteData,
              color: AppColors.worker,
              backgroundColor: AppColors.surface1,
              child: ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: _comebackRequests.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _buildComebackCard(i, _comebackRequests[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComebackCard(int index, Map<String, dynamic> req) {
    final unit = req['unit']?.toString() ?? '?';
    final time = req['time']?.toString() ?? '';
    final status = req['status']?.toString() ?? 'pending';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.home_outlined,
              size: 20,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit $unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time.length > 16 ? time.substring(0, 16) : time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (status != 'completed')
            TextButton(
              onPressed: () => _showCompleteSheet(index),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              child: const Text(
                'Complete',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            )
          else
            GlowBadge(
              label: 'Done',
              accent: AppColors.success,
              showDot: false,
            ),
        ],
      ),
    );
  }

  // ── Violations ────────────────────────────────────────────────────────────────

  Widget _buildViolationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Violations'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              RoleHeroCard(
                accent: AppColors.worker,
                eyebrow: 'DOCUMENTATION',
                title: 'Report a Violation',
                subtitle:
                    'Photograph and document rule violations per property policy',
                badgeLabel: 'Worker',
                showDot: false,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Report Violation',
                onPressed: () => Navigator.push(
                  context,
                  SharedAxisPageRoute(
                    builder: (_) => const ViolationReportScreen(),
                  ),
                ),
                accent: AppColors.error,
                icon: Icons.camera_alt_outlined,
              ),
              const SizedBox(height: 12),
              const Text(
                'Document any rule violations with a photo, violation type, '
                'and unit number. Residents are notified automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Profile ───────────────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : 'W';
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
                      backgroundColor: AppColors.worker.withValues(alpha: 0.15),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: AppColors.worker,
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _assignedProperty,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: _isOnDuty ? 'On Duty' : 'Off Duty',
                      accent: _isOnDuty ? AppColors.worker : AppColors.textMuted,
                      showDot: _isOnDuty,
                    ),
                  ],
                ),
              ),
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
                      color: AppColors.worker.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.attach_money_outlined,
                        color: AppColors.worker, size: 20),
                  ),
                  title: const Text('Earnings & Hours',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: const Text('Clock history and weekly totals',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textMuted, size: 20),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WorkerEarningsScreen())),
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
                onPressed: _signOut,
                accent: AppColors.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

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
