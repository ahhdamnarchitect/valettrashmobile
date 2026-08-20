import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/workforce/clock_hours.dart';
import 'om_worker_map_screen.dart';
import '../../../core/utils/error_reporter.dart';

/// Operations Manager: worker timecards, clock status, link to live map.
class OmWorkforceScreen extends StatefulWidget {
  const OmWorkforceScreen({
    super.key,
    required this.propertyIds,
  });

  final List<String> propertyIds;

  @override
  State<OmWorkforceScreen> createState() => _OmWorkforceScreenState();
}

class _OmWorkforceScreenState extends State<OmWorkforceScreen> {
  bool _loading = true;
  String? _error;
  int _rangeDays = 7;

  final List<Map<String, dynamic>> _workers = [];
  List<Map<String, dynamic>> _clockEvents = [];
  List<Map<String, dynamic>> _locations = [];
  final Map<String, String> _propertyNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = Supabase.instance.client;
    final propIds = widget.propertyIds;

    try {
      if (propIds.isEmpty) {
        setState(() {
          _workers.clear();
          _clockEvents = [];
          _locations = [];
          _loading = false;
        });
        return;
      }

      final props = await client
          .from('properties')
          .select('id, name')
          .filter('id', 'in', '(${propIds.join(',')})');
      for (final p in props as List) {
        final id = p['id']?.toString();
        if (id != null) _propertyNames[id] = p['name']?.toString() ?? id;
      }

      final assignments = await client
          .from('worker_assignments')
          .select(
              'user_id, property_id, users(id, first_name, last_name, email, hourly_rate)')
          .filter('property_id', 'in', '(${propIds.join(',')})')
          .eq('is_active', true);

      final byUser = <String, Map<String, dynamic>>{};
      for (final row in assignments as List) {
        final uid = row['user_id']?.toString();
        if (uid == null || uid.isEmpty) continue;
        final users = row['users'];
        Map<String, dynamic>? profile;
        if (users is Map) profile = Map<String, dynamic>.from(users);
        byUser.putIfAbsent(uid, () {
          return {
            'user_id': uid,
            'first_name': profile?['first_name']?.toString() ?? '',
            'last_name': profile?['last_name']?.toString() ?? '',
            'email': profile?['email']?.toString() ?? '',
            'hourly_rate': (profile?['hourly_rate'] as num?)?.toDouble() ?? 18,
            'property_ids': <String>{},
          };
        });
        final pid = row['property_id']?.toString();
        if (pid != null) {
          (byUser[uid]!['property_ids'] as Set<String>).add(pid);
        }
      }

      final workerIds = byUser.keys.toList();
      final since = DateTime.now()
          .subtract(Duration(days: _rangeDays))
          .toUtc()
          .toIso8601String();

      List<Map<String, dynamic>> events = [];
      List<Map<String, dynamic>> locs = [];

      if (workerIds.isNotEmpty) {
        final eventRows = await client
            .from('clock_events')
            .select('user_id, property_id, event_type, created_at')
            .filter('user_id', 'in', '(${workerIds.join(',')})')
            .gte('created_at', since)
            .order('created_at', ascending: true);
        events = List<Map<String, dynamic>>.from(eventRows as List);

        try {
          final locRows = await client
              .from('worker_locations')
              .select('user_id, property_id, latitude, longitude, updated_at')
              .filter('user_id', 'in', '(${workerIds.join(',')})');
          locs = List<Map<String, dynamic>>.from(locRows as List);
        } catch (e) {
          ErrorReporter.logSilent('om_workforce_screen.operation', e);
        }
      }

      if (!mounted) return;
      setState(() {
        _workers
          ..clear()
          ..addAll(byUser.values);
        _workers.sort((a, b) {
          final an =
              '${a['first_name']} ${a['last_name']}'.trim().toLowerCase();
          final bn =
              '${b['first_name']} ${b['last_name']}'.trim().toLowerCase();
          return an.compareTo(bn);
        });
        _clockEvents = events;
        _locations = locs;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _eventsFor(String userId) =>
      _clockEvents.where((e) => e['user_id']?.toString() == userId).toList();

  void _showWorkerDetail(Map<String, dynamic> worker) {
    final uid = worker['user_id'] as String;
    final events = _eventsFor(uid);
    final shifts = ClockHours.shiftsFromEvents(events);
    final weekStart = ClockHours.weekStartLocal();
    final weekH = ClockHours.totalHours(shifts, since: weekStart);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
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
                _workerName(worker),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This week: ${ClockHours.formatDuration(weekH)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: shifts.isEmpty
                    ? const Center(
                        child: Text(
                          'No clock events in this period.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scroll,
                        itemCount: shifts.length,
                        itemBuilder: (_, i) {
                          final s = shifts[shifts.length - 1 - i];
                          final prop = s.propertyId != null
                              ? _propertyNames[s.propertyId] ?? ''
                              : '';
                          return _shiftRow(s, prop);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shiftRow(ClockShift s, String propertyName) {
    final outLabel = s.open
        ? 'Still clocked in'
        : ClockHours.formatTimestamp(s.clockOutIso!);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            s.open ? Icons.play_circle_outline : Icons.check_circle_outline,
            color: s.open ? AppColors.success : AppColors.manager,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In: ${ClockHours.formatTimestamp(s.clockInIso)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Out: $outLabel',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (propertyName.isNotEmpty)
                  Text(
                    propertyName,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            ClockHours.formatDuration(s.hours),
            style: const TextStyle(
              color: AppColors.manager,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _workerName(Map<String, dynamic> w) {
    final name = '${w['first_name']} ${w['last_name']}'.trim();
    return name.isNotEmpty ? name : w['email']?.toString() ?? 'Worker';
  }

  bool _hasLocation(String userId) =>
      _locations.any((l) => l['user_id']?.toString() == userId);

  @override
  Widget build(BuildContext context) {
    final weekStart = ClockHours.weekStartLocal();
    var totalWeekHours = 0.0;
    var onDutyCount = 0;

    for (final w in _workers) {
      final uid = w['user_id'] as String;
      final shifts = ClockHours.shiftsFromEvents(_eventsFor(uid));
      totalWeekHours += ClockHours.totalHours(shifts, since: weekStart);
      if (ClockHours.isClockedIn(_clockEvents, userId: uid)) onDutyCount++;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Workforce & Timecards',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<int>(
            initialValue: _rangeDays,
            onSelected: (d) {
              setState(() => _rangeDays = d);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 14, child: Text('Last 14 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_rangeDays d',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.manager,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: '$onDutyCount',
                          label: 'On duty now',
                          valueColor: onDutyCount > 0
                              ? AppColors.success
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: ClockHours.formatDuration(totalWeekHours),
                          label: 'Team hours (week)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: '${_locations.length}',
                          label: 'Sharing GPS',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Live Worker Map',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OmWorkerMapScreen(),
                      ),
                    ),
                    accent: AppColors.manager,
                    icon: Icons.map_outlined,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'WORKERS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_workers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No active worker assignments for your properties.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ..._workers.map((w) => _workerCard(w)),
                ],
              ),
            ),
    );
  }

  Widget _workerCard(Map<String, dynamic> worker) {
    final uid = worker['user_id'] as String;
    final events = _eventsFor(uid);
    final shifts = ClockHours.shiftsFromEvents(events);
    final weekH =
        ClockHours.totalHours(shifts, since: ClockHours.weekStartLocal());
    final onDuty = ClockHours.isClockedIn(_clockEvents, userId: uid);
    final sharing = _hasLocation(uid);

    return GestureDetector(
      onTap: () => _showWorkerDetail(worker),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                    _workerName(worker),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Week: ${ClockHours.formatDuration(weekH)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onDuty)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: GlowBadge(
                  label: 'ON DUTY',
                  accent: AppColors.success,
                  showDot: true,
                ),
              ),
            if (sharing)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.location_on, color: AppColors.worker, size: 18),
              ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
