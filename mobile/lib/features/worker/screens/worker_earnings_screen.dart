import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/stat_tile.dart';

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _events = [];

  double get _weekHours => _computeHours(_weekStart);
  double get _monthHours => _computeHours(_monthStart);

  DateTime get _weekStart {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  double _computeHours(DateTime since) {
    double total = 0;
    DateTime? lastIn;
    for (final e in _events) {
      final ts = DateTime.parse(e['created_at'] as String).toLocal();
      if (ts.isBefore(since)) continue;
      if (e['event_type'] == 'clock_in') {
        lastIn = ts;
      } else if (e['event_type'] == 'clock_out' && lastIn != null) {
        total += ts.difference(lastIn).inMinutes / 60.0;
        lastIn = null;
      }
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();
    final rows = await Supabase.instance.client
        .from('clock_events')
        .select('event_type, created_at')
        .eq('user_id', uid)
        .gte('created_at', since)
        .order('created_at', ascending: true);
    if (mounted) {
      setState(() {
        _events = List<Map<String, dynamic>>.from(rows as List);
        _loading = false;
      });
    }
  }

  String _fmt(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  String _fmtTs(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Earnings',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [
                Row(children: [
                  StatTile(value: _fmt(_weekHours), label: 'This Week'),
                  const SizedBox(width: 8),
                  StatTile(value: _fmt(_monthHours), label: 'This Month'),
                ]),
                const SizedBox(height: 28),
                const Text('CLOCK HISTORY — LAST 30 DAYS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  const Text('No clock events yet.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14))
                else
                  ..._buildPairs(),
              ],
            ),
    );
  }

  List<Widget> _buildPairs() {
    final widgets = <Widget>[];
    DateTime? lastIn;
    String? lastInTs;
    for (final e in _events.reversed) {
      final isIn = e['event_type'] == 'clock_in';
      if (isIn) {
        lastIn = DateTime.parse(e['created_at'] as String).toLocal();
        lastInTs = e['created_at'] as String;
      } else if (!isIn && lastIn != null) {
        final out = DateTime.parse(e['created_at'] as String).toLocal();
        final hours = out.difference(lastIn).inMinutes / 60.0;
        widgets.add(_shiftTile(
            _fmtTs(lastInTs!), _fmtTs(e['created_at'] as String), _fmt(hours)));
        lastIn = null;
      }
    }
    if (lastIn != null) {
      widgets.add(_shiftTile(_fmtTs(lastInTs!), 'Still clocked in', '—'));
    }
    return widgets;
  }

  Widget _shiftTile(String inTime, String outTime, String duration) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined,
              color: AppColors.worker, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('In: $inTime',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('Out: $outTime',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(duration,
              style: const TextStyle(
                  color: AppColors.worker,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ],
      ),
    );
  }
}
