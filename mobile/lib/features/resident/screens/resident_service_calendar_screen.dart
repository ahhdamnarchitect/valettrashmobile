import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/error_reporter.dart';

class ResidentServiceCalendarScreen extends StatefulWidget {
  const ResidentServiceCalendarScreen({super.key});

  @override
  State<ResidentServiceCalendarScreen> createState() => _ResidentServiceCalendarScreenState();
}

class _ResidentServiceCalendarScreenState extends State<ResidentServiceCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<DateTime, String> _holidays = {};

  /// Service window for THIS resident's property. Defaults match the column
  /// defaults in 001_initial_schema until the real values load.
  String _windowLabel = '6:00 PM - 10:00 PM';
  String? _propertyName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _holidays = ServiceSchedule.federalHolidays(_selectedMonth.year);
    _loadServiceWindow();
  }

  /// Reads the service window from the resident's own property.
  ///
  /// This screen used to hardcode "6:00 PM - 10:00 PM" for everyone, which is
  /// simply wrong for any property on a different schedule - Oakwood Heights runs
  /// 5:30-9:30 PM. properties.service_window_start/end are per-property columns.
  Future<void> _loadServiceWindow() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('resident_units')
          .select('properties(name, service_window_start, service_window_end)')
          .eq('user_id', uid)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      final prop = row?['properties'] as Map<String, dynamic>?;
      if (prop == null || !mounted) return;
      setState(() {
        _propertyName = prop['name']?.toString();
        _windowLabel =
            '${ServiceSchedule.formatTime(prop['service_window_start'])} - ${ServiceSchedule.formatTime(prop['service_window_end'])}';
      });
    } catch (e) {
      ErrorReporter.logSilent('service calendar: load window', e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }






  bool _isHoliday(DateTime date) {
    return _holidays.containsKey(DateTime(date.year, date.month, date.day));
  }

  String _getServiceStatus(DateTime date) {
    if (_isHoliday(date)) {
      return 'Holiday: ${_holidays[DateTime(date.year, date.month, date.day)]}';
    }
    if (ServiceSchedule.isServiceDay(date)) {
      return 'Service Active ($_windowLabel)';
    }
    return 'No Service Day';
  }

  Color _getDateColor(DateTime date) {
    if (_isHoliday(date)) return Colors.red;
    if (ServiceSchedule.isServiceDay(date)) return Colors.green;
    return Colors.red;
  }

  void _changeMonth(int direction) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + direction);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _showDateDetails(date);
  }

  void _showDateDetails(DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${date.month}/${date.day}/${date.year}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getDateColor(date).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getDateColor(date)),
              ),
              child: Row(
                children: [
                  Icon(
                    ServiceSchedule.isServiceDay(date) && !_isHoliday(date) 
                        ? Icons.check_circle 
                        : Icons.cancel,
                    color: _getDateColor(date),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getServiceStatus(date),
                      style: TextStyle(
                        color: _getDateColor(date),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isHoliday(date)) ...[
              const Text(
                'Service is canceled for this holiday.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else if (ServiceSchedule.isServiceDay(date)) ...[
              const Text(
                'Trash pickup service is available tonight.',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ] else ...[
              const Text(
                'No trash service scheduled for this day.',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCalendarDays() {
    final days = <Widget>[];
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final startDate = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday % 7));

    // Day headers
    const dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (final header in dayHeaders) {
      days.add(
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            header,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Calendar days
    for (int i = 0; i < 42; i++) {
      final date = startDate.add(Duration(days: i));
      final isCurrentMonth = date.month == _selectedMonth.month;
      final isSelected = _selectedDate != null && 
          date.day == _selectedDate!.day && 
          date.month == _selectedDate!.month && 
          date.year == _selectedDate!.year;
      final isToday = date.day == DateTime.now().day && 
          date.month == DateTime.now().month && 
          date.year == DateTime.now().year;

      days.add(
        GestureDetector(
          onTap: () => _selectDate(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.blue.shade600 
                  : isToday 
                      ? Colors.blue.shade100 
                      : Colors.transparent,
              border: Border.all(
                color: isSelected 
                    ? Colors.blue.shade600 
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: isSelected || isToday 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: isCurrentMonth 
                          ? Colors.black87 
                          : Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                  if (_isHoliday(date)) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Service Calendar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              // Month Navigation
              Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => _changeMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        '${_selectedMonth.month}/${_selectedMonth.year}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _changeMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Calendar
              Container(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegendItem('Service Day', Colors.green),
                          _buildLegendItem('No Service', Colors.red),
                          _buildLegendItem('Holiday', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Calendar Grid
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 7,
                        childAspectRatio: 1.2,
                        children: _buildCalendarDays(),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info Card
              Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Service Schedule',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Make it explicit whose schedule this is - the window is
                      // per-property, so an unlabelled time is ambiguous.
                      Text(
                        _loading
                            ? 'Loading your property schedule...'
                            : (_propertyName ?? 'Your property'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildScheduleItem('Sunday - Thursday', _windowLabel, Colors.green),
                      _buildScheduleItem('Friday - Saturday', 'No Service', Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        'Tap any date to see service details and holiday information.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem(String days, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              days,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pure date rules behind the service calendar, kept separate so they can be
/// tested directly. Both were wrong before: the floating federal holidays were
/// pinned to fixed dates (so every one was off in any other year), and Sunday was
/// excluded from service days while the screen's own legend said "Sunday - Thursday".
class ServiceSchedule {
  const ServiceSchedule._();

  /// The nth [weekday] of [month], e.g. the 3rd Monday of January.
  static DateTime nthWeekday(int year, int month, int weekday, int n) {
    final first = DateTime(year, month, 1);
    final offset = (weekday - first.weekday + 7) % 7;
    return DateTime(year, month, 1 + offset + (n - 1) * 7);
  }

  /// The last [weekday] of [month], e.g. the last Monday of May.
  static DateTime lastWeekday(int year, int month, int weekday) {
    final last = DateTime(year, month + 1, 0);
    final offset = (last.weekday - weekday + 7) % 7;
    return DateTime(year, month, last.day - offset);
  }

  /// Observed US federal holidays for [year]. Computed, not hardcoded, so the
  /// calendar stays correct as the year rolls over.
  static Map<DateTime, String> federalHolidays(int year) => {
        DateTime(year, 1, 1): "New Year's Day",
        nthWeekday(year, 1, DateTime.monday, 3): 'Martin Luther King Jr. Day',
        lastWeekday(year, 5, DateTime.monday): 'Memorial Day',
        DateTime(year, 7, 4): 'Independence Day',
        nthWeekday(year, 9, DateTime.monday, 1): 'Labor Day',
        DateTime(year, 11, 11): 'Veterans Day',
        nthWeekday(year, 11, DateTime.thursday, 4): 'Thanksgiving Day',
        DateTime(year, 12, 25): 'Christmas Day',
      };

  /// Sunday through Thursday. DateTime.weekday is Mon=1..Sun=7.
  static bool isServiceDay(DateTime date) =>
      date.weekday <= DateTime.thursday || date.weekday == DateTime.sunday;

  /// '18:00:00' -> '6:00 PM'
  static String formatTime(dynamic raw) {
    final parts = (raw?.toString() ?? '').split(':');
    if (parts.length < 2) return '--';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }
}
