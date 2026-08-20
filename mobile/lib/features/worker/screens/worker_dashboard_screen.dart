import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/platform/geo_helper_stub.dart'
    // ignore: uri_does_not_exist
    if (dart.library.html) '../../../core/platform/geo_helper_web.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/storage/photo_storage.dart';
import '../../../core/utils/error_reporter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/role_bottom_nav.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../../core/utils/page_transitions.dart';
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
  String? _firstName;
  bool _isOnDuty = false;
  String _assignedProperty = 'No property assigned';
  List<Map<String, String>> _assignedProperties = [];
  String? _propertyId;
  String? _activeRouteId;
  String? _activeRunId;
  DateTime? _clockedInAt;

  // Stops / Scan
  List<Map<String, dynamic>> _stops = [];
  int _completedStopCount = 0;
  int _currentStopIndex = 0;
  bool _isCompletingStop = false;

  // Comebacks
  List<Map<String, dynamic>> _comebackRequests = [];

  // Messages
  List<Map<String, dynamic>> _conversations = [];
  RealtimeChannel? _msgChannel;
  bool _messagesLoaded = false;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _loadRouteData();
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    super.dispose();
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
      // Profile
      try {
        final profile = await client
            .from('users')
            .select('first_name')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          _firstName = profile['first_name']?.toString();
        }
      } catch (e) {
        ErrorReporter.logSilent('worker_dashboard_screen._loadRouteData', e);
      }

      // Worker assignments
      final assigns = await client
          .from('worker_assignments')
          .select('property_id, properties(name)')
          .eq('user_id', user.id)
          .eq('is_active', true);
      final assignList = List<Map<String, dynamic>>.from(assigns as List);
      final names = <String>[];
      final propertyIds = <String>{};
      final entries = <Map<String, String>>[];
      for (final row in assignList) {
        final pid = row['property_id']?.toString();
        if (pid == null) continue;
        final p = row['properties'];
        final pname = p is Map && p['name'] != null
            ? p['name'].toString()
            : 'Property';
        names.add(pname);
        propertyIds.add(pid);
        entries.add({'id': pid, 'name': pname});
      }
      _assignedProperties = entries;
      if (names.isNotEmpty) {
        _assignedProperty = names.join(', ');
      } else {
        _assignedProperty = 'No property assigned';
      }
      if (propertyIds.isNotEmpty) {
        final keepCurrent =
            _propertyId != null && propertyIds.contains(_propertyId);
        if (!keepCurrent) _propertyId = propertyIds.first;
      } else {
        _propertyId = null;
      }

      // Active route
      final routes = await client
          .from('routes')
          .select('id, name')
          .eq('worker_id', user.id)
          .eq('is_active', true);
      final routeList = List<Map<String, dynamic>>.from(routes as List);
      if (routeList.isNotEmpty) {
        _activeRouteId = routeList.first['id']?.toString();
      }

      // Active nightly run for property
      if (_propertyId != null) {
        try {
          final today = DateTime.now();
          final dateStr =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          final runs = await client
              .from('nightly_runs')
              .select('id')
              .eq('property_id', _propertyId!)
              .eq('run_date', dateStr)
              .limit(1);
          final runList = List<Map<String, dynamic>>.from(runs as List);
          if (runList.isNotEmpty) {
            _activeRunId = runList.first['id']?.toString();
          }
        } catch (e) {
          ErrorReporter.logSilent('worker_dashboard_screen.operation', e);
        }
      }

      // Load stops if we have an active route
      if (_activeRouteId != null) {
        await _loadStops();
      }

      // Comeback requests for assigned properties
      final rawComebacks = await client
          .from('missed_pickup_requests')
          .select(
              'id, status, requested_at, payment_status, pickups(units(unit_number), nightly_runs(property_id))')
          .limit(80);
      final cbList = List<Map<String, dynamic>>.from(rawComebacks as List);
      _comebackRequests = [];
      for (final row in cbList) {
        final pay = row['payment_status']?.toString();
        if (pay == 'pending_payment') continue;
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

      // Clock-in state
      try {
        final lastEvent = await client
            .from('clock_events')
            .select('event_type, created_at')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (lastEvent != null && lastEvent['event_type'] == 'clock_in') {
          _isOnDuty = true;
          final ts = lastEvent['created_at']?.toString();
          if (ts != null) _clockedInAt = DateTime.tryParse(ts);
        }
      } catch (e) {
        ErrorReporter.logSilent('worker_dashboard_screen.operation', e);
      }
    } catch (_) {
      _comebackRequests = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStops() async {
    if (_activeRouteId == null) return;
    try {
      final stopsData = await Supabase.instance.client
          .from('route_stops')
          .select('id, stop_order, unit_id, units(unit_number)')
          .eq('route_id', _activeRouteId!)
          .order('stop_order');

      final allStops = List<Map<String, dynamic>>.from(stopsData as List);

      // Filter out completed stops for today's run
      Set<String> completedIds = {};
      if (_activeRunId != null) {
        try {
          final completed = await Supabase.instance.client
              .from('stop_completions')
              .select('stop_id')
              .eq('run_id', _activeRunId!);
          completedIds = (completed as List)
              .map((c) => c['stop_id'].toString())
              .toSet();
        } catch (e) {
          ErrorReporter.logSilent('worker_dashboard_screen._loadStops', e);
        }
      }

      final remaining = allStops.where((s) => !completedIds.contains(s['id']?.toString())).map((s) {
        final unit = s['units'] as Map?;
        return {
          'id': s['id']?.toString() ?? '',
          'unit_id': s['unit_id']?.toString() ?? '',
          'unit_number': unit?['unit_number']?.toString() ?? 'Unit',
          'stop_order': s['stop_order'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _stops = remaining;
          _completedStopCount = completedIds.length;
          _currentStopIndex = 0;
        });
      }
    } catch (e) {
      ErrorReporter.logSilent('worker_dashboard_screen._loadStops', e);
    }
  }

  Future<void> _completeStop(String stopId,
      {String? photoUrl, required String method}) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('stop_completions').insert({
      'stop_id': stopId,
      'run_id': _activeRunId,
      'completed_by': uid,
      'photo_url': photoUrl,
      'method': method,
    });
  }

  Future<void> _loadMessages() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final msgs = await Supabase.instance.client
          .from('direct_messages')
          .select(
              '*, sender:users!sender_id(first_name, last_name), recipient:users!recipient_id(first_name, last_name)')
          .or('sender_id.eq.$uid,recipient_id.eq.$uid')
          .order('created_at', ascending: false);

      final Map<String, Map<String, dynamic>> convMap = {};
      for (final m in (msgs as List)) {
        final senderId = m['sender_id']?.toString();
        final recipientId = m['recipient_id']?.toString();
        final isMe = senderId == uid;
        final partnerId = isMe ? recipientId : senderId;
        if (partnerId == null) continue;
        final partner = isMe ? m['recipient'] : m['sender'];
        final partnerName =
            '${partner?['first_name'] ?? ''} ${partner?['last_name'] ?? ''}'
                .trim();
        if (!convMap.containsKey(partnerId)) {
          convMap[partnerId] = {
            'partner_id': partnerId,
            'partner_name': partnerName.isEmpty ? 'Unknown' : partnerName,
            'last_message': m['body'],
            'last_time': m['created_at'],
            'unread': (!isMe && m['read_at'] == null) ? 1 : 0,
          };
        } else if (!isMe && m['read_at'] == null) {
          convMap[partnerId]!['unread'] =
              (convMap[partnerId]!['unread'] as int) + 1;
        }
      }
      if (mounted) setState(() => _conversations = convMap.values.toList());
    } catch (e) {
      ErrorReporter.logSilent('worker_dashboard_screen._loadMessages', e);
    }
  }

  void _subscribeMessages() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _msgChannel = Supabase.instance.client
        .channel('worker_dm_$uid')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: 'INSERT',
            schema: 'public',
            table: 'direct_messages',
            filter: 'recipient_id=eq.$uid',
          ),
          (payload, [ref]) => _loadMessages(),
        );
    _msgChannel?.subscribe();
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
      } catch (e) {
        // Was swallowed, and the row was then removed from the list anyway - so the
        // comeback vanished from the worker's screen while still sitting pending in
        // the database. Keep it visible and say what happened.
        ErrorReporter.showError(
          mounted ? context : null,
          'Could not mark this comeback complete - it stays on your list',
          error: e,
          logContext: 'missed_pickup_requests complete',
        );
        return;
      }
    }
    if (mounted) {
      setState(() => _comebackRequests.removeAt(index));
      _snack('Comeback completed');
    }
  }

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
                Text(
                  'Mark Pickup Complete',
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Optionally add a proof-of-pickup photo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
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
                    } catch (e) {
                      ErrorReporter.logSilent('worker_dashboard_screen._showCompleteSheet', e);
                    }
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
                                  color: AppColors.textSecondary, size: 28),
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
                                if (photoBytes != null && photoName != null) {
                                  try {
                                    await PhotoStorage.uploadWorkerPhoto(
                                      photoBytes!,
                                      kind: 'pickup_proofs',
                                      ext: photoName!.split('.').last,
                                    );
                                  } catch (e) {
                                    // Surface it: this used to fail silently on
                                    // every upload (wrong bucket prefix -> 403).
                                    _snack('Photo upload failed - saving without it');
                                  }
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                                _completeComebackRequest(index);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
    if (newState && _propertyId == null) {
      _snack(
          'No property assigned yet. Ask your admin to assign you under Worker Assignments.');
      return;
    }
    final previousOnDuty = _isOnDuty;
    final previousClockedInAt = _clockedInAt;
    setState(() {
      _isOnDuty = newState;
      _clockedInAt = newState ? DateTime.now() : null;
    });
    try {
      await Supabase.instance.client.from('clock_events').insert({
        'user_id': uid,
        'event_type': newState ? 'clock_in' : 'clock_out',
        'property_id': _propertyId,
      });
    } catch (e) {
      // This used to be swallowed while the UI still switched to ON DUTY and said
      // so. The clock event drives payroll, so a silent failure meant unpaid hours
      // and a worker with no reason to suspect anything. Roll the state back.
      if (mounted) {
        setState(() {
          _isOnDuty = previousOnDuty;
          _clockedInAt = previousClockedInAt;
        });
      }
      ErrorReporter.showError(
        mounted ? context : null,
        newState
            ? 'Could not clock in - check your connection and try again'
            : 'Could not clock out - check your connection and try again',
        error: e,
        logContext: 'clock_events insert',
      );
      return;
    }
    _snack(newState
        ? 'You are on duty — residents at this property will see ON DUTY'
        : 'You are now off duty');
  }

  Future<void> _shareLocation() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final coords = await getPlatformLocation();
      if (coords == null) {
        _snack('Location unavailable on this platform');
        return;
      }
      await Supabase.instance.client.from('worker_locations').upsert({
        'user_id': uid,
        'property_id': _propertyId,
        'latitude': coords['lat'],
        'longitude': coords['lng'],
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

  String _timeOnRoute() {
    if (_clockedInAt == null) return '--';
    final diff = DateTime.now().difference(_clockedInAt!);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
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
              onTap: (i) {
                setState(() => _tabIndex = i);
                if (i == 3 && !_messagesLoaded) {
                  _messagesLoaded = true;
                  _loadMessages();
                  _subscribeMessages();
                }
              },
              accent: AppColors.worker,
              items: const [
                RoleNavItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: 'Route'),
                RoleNavItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt,
                    label: 'Stops'),
                RoleNavItem(
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    label: 'Scan'),
                RoleNavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: 'Messages'),
                RoleNavItem(
                    icon: Icons.more_horiz,
                    activeIcon: Icons.more_horiz,
                    label: 'More'),
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
        return _buildStopsTab();
      case 2:
        return _buildScanTab();
      case 3:
        return _buildMessagesTab();
      default:
        return _buildMoreTab();
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
          SkeletonCard(height: 100),
          SizedBox(height: 12),
          SkeletonCard(height: 56),
        ],
      );
    }
    final totalStops = _stops.length + _completedStopCount;

    return RefreshIndicator(
      onRefresh: _loadRouteData,
      color: AppColors.worker,
      backgroundColor: AppColors.surface1,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: [
          // Greeting
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${_firstName ?? 'there'}',
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You have ${_stops.length + _completedStopCount} stops today',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              GlowBadge(
                label: _isOnDuty ? 'On Duty' : 'Off Duty',
                accent: _isOnDuty ? AppColors.success : AppColors.textSecondary,
                showDot: _isOnDuty,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_assignedProperties.isEmpty)
            BentoCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are not assigned to a property yet. Your admin must assign you under Tools → Worker Assignments, then pull to refresh.',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35),
                    ),
                  ),
                ],
              ),
            )
          else if (_assignedProperties.length > 1) ...[
            Text(
              'ASSIGNED PROPERTIES',
              style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assignedProperties.map((p) {
                final selected = _propertyId == p['id'];
                return ChoiceChip(
                  label: Text(p['name'] ?? ''),
                  selected: selected,
                  onSelected: (_) => setState(() => _propertyId = p['id']),
                  selectedColor: AppColors.rlvBlue.withValues(alpha: 0.25),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.rlvBlue
                        : AppColors.textSecondary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // Bento row: donut + stats
          Row(
            children: [
              Expanded(
                flex: 2,
                child: BentoCard(
                  height: 160,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROGRESS',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: totalStops == 0
                            ? Center(
                                child: Text('No stops',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      centerSpaceRadius: 28,
                                      sectionsSpace: 2,
                                      sections: [
                                        PieChartSectionData(
                                          value: _completedStopCount.toDouble(),
                                          color: AppColors.success,
                                          radius: 18,
                                          title: '',
                                        ),
                                        PieChartSectionData(
                                          value: _stops.length.toDouble(),
                                          color: AppColors.surface2,
                                          radius: 18,
                                          title: '',
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_completedStopCount + _stops.length > 0)
                                    Text(
                                      '${(_completedStopCount / (_completedStopCount + _stops.length) * 100).round()}%',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      Text(
                        '$_completedStopCount of $totalStops Stops Complete',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    BentoCard(
                      height: 74,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined,
                              color: AppColors.rlvBlue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'PROPERTY',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _assignedProperty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BentoCard(
                      height: 74,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: AppColors.rlvBlue, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'TIME ON ROUTE',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isOnDuty ? _timeOnRoute() : '--',
                                style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_stops.isNotEmpty)
            BentoCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.rlvBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: AppColors.rlvBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT STOP',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Unit ${_stops[_currentStopIndex]['unit_number']}',
                          style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        Text(
                          _assignedProperty,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _toggleDuty,
              icon: Icon(_isOnDuty
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
              label: Text(
                _isOnDuty ? 'Clock Out' : 'Clock In',
                style: GoogleFonts.montserrat(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnDuty ? AppColors.error : AppColors.rlvBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
              side: BorderSide(
                  color: _isOnDuty ? AppColors.worker : AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stops ─────────────────────────────────────────────────────────────────────

  Widget _buildStopsTab() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        children: const [
          SkeletonCard(height: 56),
          SizedBox(height: 8),
          SkeletonCard(height: 56),
          SizedBox(height: 8),
          SkeletonCard(height: 56),
        ],
      );
    }

    final totalStops = _stops.length + _completedStopCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stops',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$_completedStopCount/$totalStops',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (totalStops > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalStops == 0 ? 0 : _completedStopCount / totalStops,
                backgroundColor: AppColors.surface2,
                color: AppColors.success,
                minHeight: 4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: _stops.isEmpty && _completedStopCount == 0
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.list_alt,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        _activeRouteId == null
                            ? 'No active route assigned'
                            : 'No stops on route',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: _stops.isEmpty ? 1 : _stops.length,
                  itemBuilder: (context, i) {
                    if (_stops.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 48, color: AppColors.success),
                              const SizedBox(height: 12),
                              Text(
                                'All stops complete!',
                                style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final stop = _stops[i];
                    final isNext = i == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isNext
                            ? AppColors.rlvBlue.withValues(alpha: 0.08)
                            : AppColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isNext
                              ? AppColors.rlvBlue.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isNext
                                  ? AppColors.rlvBlue.withValues(alpha: 0.15)
                                  : AppColors.surface2,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${_completedStopCount + i + 1}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isNext
                                      ? AppColors.rlvBlue
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              stop['unit_number'] as String,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isNext)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.rlvBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'NEXT',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.rlvBlue,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Scan ──────────────────────────────────────────────────────────────────────

  Widget _buildScanTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.rlvBlue));
    }

    final totalStops = _stops.length + _completedStopCount;

    if (_stops.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text(
              totalStops > 0 ? 'All stops complete!' : 'No stops assigned',
              style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            if (totalStops > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$_completedStopCount stops done',
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      );
    }

    final stopIndex = _currentStopIndex < _stops.length ? _currentStopIndex : 0;
    final stop = _stops[stopIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CURRENT STOP',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_completedStopCount + 1} of $totalStops',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.rlvBlue,
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalStops == 0 ? 0 : _completedStopCount / totalStops,
              backgroundColor: AppColors.surface2,
              color: AppColors.success,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 20),
          BentoCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop['unit_number'] as String,
                  style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _assignedProperty,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isCompletingStop ? null : () => _photoConfirmStop(stop),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      'Photo',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface1,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isCompletingStop ? null : () => _manualCompleteStop(stop),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.rlvBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isCompletingStop
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text(
                            'Mark Done',
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isCompletingStop ? null : () => _flagComeback(stop),
            icon: const Icon(Icons.flag_outlined, color: AppColors.error),
            label: Text(
              'Flag Comeback',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _photoConfirmStop(Map<String, dynamic> stop) async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image == null) return;
    setState(() => _isCompletingStop = true);
    try {
      final bytes = await image.readAsBytes();
      final stopId = stop['id'] as String;
      // Was bucket 'pickup-photos', which does not exist, with getPublicUrl() on
      // what is a private bucket. Store the path; sign it on read.
      final path = await PhotoStorage.uploadWorkerPhoto(bytes, kind: 'stops');
      await _completeStop(stopId, photoUrl: path, method: 'photo');
      _advanceStop();
    } catch (e) {
      _snack('Photo upload failed — try again');
    } finally {
      if (mounted) setState(() => _isCompletingStop = false);
    }
  }

  Future<void> _manualCompleteStop(Map<String, dynamic> stop) async {
    setState(() => _isCompletingStop = true);
    try {
      await _completeStop(stop['id'] as String, method: 'manual');
      _advanceStop();
    } catch (e) {
      _snack('Could not mark stop complete');
    } finally {
      if (mounted) setState(() => _isCompletingStop = false);
    }
  }

  void _advanceStop() {
    if (!mounted) return;
    setState(() {
      _completedStopCount++;
      if (_stops.isNotEmpty) _stops.removeAt(0);
      _currentStopIndex = 0;
    });
  }

  Future<void> _flagComeback(Map<String, dynamic> stop) async {
    try {
      await Supabase.instance.client.from('missed_pickup_requests').insert({
        'unit_id': stop['unit_id'],
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Previously swallowed, and then _snack said "Comeback flagged" regardless.
      // A resident who reported a missed pickup would simply never be serviced.
      ErrorReporter.showError(
        mounted ? context : null,
        'Could not flag this comeback - please try again',
        error: e,
        logContext: 'missed_pickup_requests insert',
      );
      return;
    }
    _snack('Comeback flagged');
    _advanceStop();
  }

  // ── Messages ──────────────────────────────────────────────────────────────────

  Widget _buildMessagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'Messages',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text('No messages yet',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: AppColors.border, height: 1),
                  itemBuilder: (_, i) {
                    final c = _conversations[i];
                    final name = c['partner_name'] as String? ?? 'Unknown';
                    final unread = c['unread'] as int? ?? 0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.rlvBlue.withValues(alpha: 0.15),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              color: AppColors.rlvBlue),
                        ),
                      ),
                      title: Text(name,
                          style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      subtitle: Text(
                        c['last_message'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      trailing: unread > 0
                          ? Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  color: AppColors.rlvBlue,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '$unread',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                              ),
                            )
                          : null,
                      onTap: () => _openConversation(
                          c['partner_id'] as String, name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openConversation(String partnerId, String partnerName) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _WorkerConversationScreen(
                partnerId: partnerId, partnerName: partnerName)));
    _loadMessages();
  }

  // ── More ──────────────────────────────────────────────────────────────────────

  Widget _buildMoreTab() {
    final initial = _email.isNotEmpty ? _email[0].toUpperCase() : 'W';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            'More',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              // Profile card
              BentoCard(
                padding: const EdgeInsets.all(16),
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
                            _firstName ?? _email,
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _assignedProperty,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GlowBadge(
                      label: _isOnDuty ? 'On Duty' : 'Off Duty',
                      accent:
                          _isOnDuty ? AppColors.success : AppColors.textSecondary,
                      showDot: _isOnDuty,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_comebackRequests.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comebacks',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GlowBadge(
                      label: '${_comebackRequests.length} pending',
                      accent: AppColors.warning,
                      showDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...List.generate(
                  _comebackRequests.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildComebackCard(i, _comebackRequests[i]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Violation reporting is a core part of the service (bag rules,
              // prohibited items). ViolationReportScreen was fully built but had
              // no entry point anywhere in the app, so no worker could ever file one.
              BentoCard(
                padding: EdgeInsets.zero,
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
                    child: const Icon(Icons.report_problem_outlined,
                        color: AppColors.warning, size: 20),
                  ),
                  title: Text('Report a Violation',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('Bag rules, prohibited items, photo evidence',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 20),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ViolationReportScreen())),
                ),
              ),
              const SizedBox(height: 10),
              BentoCard(
                padding: EdgeInsets.zero,
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
                  title: Text('Earnings & Hours',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text('Clock history and weekly totals',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary, size: 20),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WorkerEarningsScreen())),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Change Password',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
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
            child: const Icon(Icons.home_outlined,
                size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unit $unit',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  time.length > 16 ? time.substring(0, 16) : time,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (status != 'completed')
            TextButton(
              onPressed: () => _showCompleteSheet(index),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text('Complete',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            )
          else
            GlowBadge(label: 'Done', accent: AppColors.success, showDot: false),
        ],
      ),
    );
  }
}

// ── Worker Conversation Screen ────────────────────────────────────────────────

class _WorkerConversationScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;
  const _WorkerConversationScreen(
      {required this.partnerId, required this.partnerName});

  @override
  State<_WorkerConversationScreen> createState() =>
      _WorkerConversationScreenState();
}

class _WorkerConversationScreenState
    extends State<_WorkerConversationScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  RealtimeChannel? _channel;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final msgs = await Supabase.instance.client
          .from('direct_messages')
          .select()
          .or('and(sender_id.eq.$uid,recipient_id.eq.${widget.partnerId}),and(sender_id.eq.${widget.partnerId},recipient_id.eq.$uid)')
          .order('created_at');
      await Supabase.instance.client
          .from('direct_messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('sender_id', widget.partnerId)
          .eq('recipient_id', uid)
          .filter('read_at', 'is', 'null');
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(msgs));
      }
    } catch (e) {
      ErrorReporter.showError(mounted ? context : null, 'Could not load messages',
          error: e, logContext: 'direct_messages load');
    }
  }

  void _subscribe() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _channel = Supabase.instance.client
        .channel('wconv_${uid}_${widget.partnerId}')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
              event: 'INSERT', schema: 'public', table: 'direct_messages'),
          (payload, [ref]) => _load(),
        );
    _channel?.subscribe();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _ctrl.clear();
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('direct_messages').insert({
        'sender_id': uid,
        'recipient_id': widget.partnerId,
        'body': text,
      });
      await _load();
    } catch (e) {
      // The field was cleared before the insert, so a swallowed failure meant the
      // worker watched their message disappear and assumed it sent. Restore it.
      _ctrl.text = text;
      ErrorReporter.showError(mounted ? context : null,
          'Message not sent - tap send to try again',
          error: e, logContext: 'direct_messages send');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        title: Text(widget.partnerName,
            style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('No messages yet',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 14)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMe = m['sender_id'] == uid;
                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.rlvBlue
                                : AppColors.surface1,
                            borderRadius: BorderRadius.circular(16),
                            border: isMe
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            m['body'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                color: isMe
                                    ? Colors.white
                                    : AppColors.textPrimary),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface1,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.surface2,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.rlvBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
