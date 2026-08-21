import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../core/workforce/clock_hours.dart';
import '../../../core/utils/error_reporter.dart';

/// Owner: labor cost from clock hours × hourly rate; edit driver pay rates.
class OwnerWorkforceScreen extends StatefulWidget {
  const OwnerWorkforceScreen({super.key});

  @override
  State<OwnerWorkforceScreen> createState() => _OwnerWorkforceScreenState();
}

class _OwnerWorkforceScreenState extends State<OwnerWorkforceScreen> {
  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _clockEvents = [];
  List<Map<String, dynamic>> _payouts = [];

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
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();

    try {
      final driverRows = await client
          .from('users')
          .select('id, first_name, last_name, email, hourly_rate')
          .eq('role', 'driver')
          .eq('is_active', true)
          .order('last_name');

      final drivers = List<Map<String, dynamic>>.from(driverRows as List);
      final ids = drivers
          .map((d) => d['id']?.toString())
          .whereType<String>()
          .toList();

      List<Map<String, dynamic>> events = [];
      if (ids.isNotEmpty) {
        final eventRows = await client
            .from('clock_events')
            .select('user_id, property_id, event_type, created_at')
            .filter('user_id', 'in', '(${ids.join(',')})')
            .gte('created_at', since)
            .order('created_at', ascending: true);
        events = List<Map<String, dynamic>>.from(eventRows as List);
      }

      List<Map<String, dynamic>> payouts = [];
      try {
        final payoutRows = await client
            .from('contractor_payouts')
            .select('amount, status, created_at, worker_user_id')
            .gte('created_at', since)
            .order('created_at', ascending: false);
        payouts = List<Map<String, dynamic>>.from(payoutRows as List);
      } catch (e) {
        ErrorReporter.logSilent('owner_workforce_screen._load', e);
      }

      if (!mounted) return;
      setState(() {
        _drivers
          ..clear()
          ..addAll(drivers);
        _clockEvents = events;
        _payouts = payouts;
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

  double _rate(Map<String, dynamic> d) =>
      (d['hourly_rate'] as num?)?.toDouble() ?? 18.0;

  ({double weekHours, double monthHours, double weekCost, double monthCost})
      _totalsFor(String userId, double rate) {
    final shifts = ClockHours.shiftsFromEvents(_eventsFor(userId));
    final weekH =
        ClockHours.totalHours(shifts, since: ClockHours.weekStartLocal());
    final monthH =
        ClockHours.totalHours(shifts, since: ClockHours.monthStartLocal());
    return (
      weekHours: weekH,
      monthHours: monthH,
      weekCost: ClockHours.laborCost(hours: weekH, hourlyRate: rate),
      monthCost: ClockHours.laborCost(hours: monthH, hourlyRate: rate),
    );
  }

  double get _portfolioWeekCost {
    var sum = 0.0;
    for (final d in _drivers) {
      final id = d['id']?.toString() ?? '';
      sum += _totalsFor(id, _rate(d)).weekCost;
    }
    return sum;
  }

  double get _portfolioMonthCost {
    var sum = 0.0;
    for (final d in _drivers) {
      final id = d['id']?.toString() ?? '';
      sum += _totalsFor(id, _rate(d)).monthCost;
    }
    return sum;
  }

  double get _loggedPayoutsMonth {
    final monthStart = ClockHours.monthStartLocal().toUtc();
    var sum = 0.0;
    for (final p in _payouts) {
      final created = p['created_at'] as String?;
      if (created == null) continue;
      if (DateTime.parse(created).isBefore(monthStart)) continue;
      final status = p['status']?.toString();
      if (status == 'paid' || status == 'processing' || status == 'pending') {
        sum += (p['amount'] as num?)?.toDouble() ?? 0;
      }
    }
    return sum;
  }

  Future<void> _editRate(Map<String, dynamic> driver) async {
    final id = driver['id']?.toString();
    if (id == null) return;
    final controller = TextEditingController(
      text: _rate(driver).toStringAsFixed(2),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: Text(
          'Hourly rate',
          style: GoogleFonts.montserrat(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Per hour (USD)',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final rate = double.tryParse(controller.text.trim());
    if (rate == null || rate < 0) return;

    try {
      await Supabase.instance.client.rpc(
        'set_worker_hourly_rate',
        params: {'p_worker_id': id, 'p_rate': rate},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hourly rate updated')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rate: $e')),
        );
      }
    }
  }

  String _name(Map<String, dynamic> d) {
    final n = '${d['first_name']} ${d['last_name']}'.trim();
    return n.isNotEmpty ? n : d['email']?.toString() ?? 'Driver';
  }

  @override
  Widget build(BuildContext context) {
  final c = context.roleColors;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface1,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Labor & Payroll',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: c.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.owner,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                  Text(
                    'Estimated labor from clock in/out × hourly rate. '
                    'Logged contractor payouts may differ until Stripe sync is live.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: c.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: ClockHours.formatMoney(_portfolioWeekCost),
                          label: 'Est labor (week)',
                          valueColor: AppColors.owner,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatTile(
                          value: ClockHours.formatMoney(_portfolioMonthCost),
                          label: 'Est labor (month)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          value: ClockHours.formatMoney(_loggedPayoutsMonth),
                          label: 'Payouts logged (mo)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'DRIVERS',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_drivers.isEmpty)
                    Text('No active drivers.', style: TextStyle(color: c.textMuted))
                  else
                    ..._drivers.map((d) => _driverCard(d, c)),
                ],
              ),
            ),
    );
  }

  Widget _driverCard(Map<String, dynamic> d, AppColorsScheme c) {
    final id = d['id']?.toString() ?? '';
    final rate = _rate(d);
    final t = _totalsFor(id, rate);
    final onDuty = ClockHours.isClockedIn(_clockEvents, userId: id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _name(d),
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onDuty)
                const GlowBadge(
                  label: 'ON DUTY',
                  accent: AppColors.success,
                  showDot: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${ClockHours.formatMoney(rate)}/hr · '
            'Week ${ClockHours.formatDuration(t.weekHours)} '
            '(${ClockHours.formatMoney(t.weekCost)}) · '
            'Month ${ClockHours.formatMoney(t.monthCost)}',
            style: TextStyle(color: c.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _editRate(d),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit hourly rate'),
            ),
          ),
        ],
      ),
    );
  }
}
