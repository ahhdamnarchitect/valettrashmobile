import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResidentServiceCalendarScreen extends StatefulWidget {
  const ResidentServiceCalendarScreen({super.key});

  @override
  State<ResidentServiceCalendarScreen> createState() => _ResidentServiceCalendarScreenState();
}

class _ResidentServiceCalendarScreenState extends State<ResidentServiceCalendarScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDate;
  Map<DateTime, String> _holidays = {};

  @override
  void initState() {
    super.initState();
    _loadMockHolidays();
  }

  void _loadMockHolidays() {
    final now = DateTime.now();
    _holidays = {
      DateTime(now.year, 1, 1): 'New Year\'s Day',
      DateTime(now.year, 7, 4): 'Independence Day',
      DateTime(now.year, 12, 25): 'Christmas Day',
      DateTime(now.year, 1, 15): 'Martin Luther King Jr. Day',
      DateTime(now.year, 5, 27): 'Memorial Day',
      DateTime(now.year, 9, 2): 'Labor Day',
      DateTime(now.year, 11, 11): 'Veterans Day',
      DateTime(now.year, 11, 28): 'Thanksgiving Day',
    };
  }

  bool _isServiceDay(DateTime date) {
    // Service days: Sunday (7) through Thursday (4)
    // No service: Friday (5) and Saturday (6)
    return date.weekday <= 4;
  }

  bool _isHoliday(DateTime date) {
    return _holidays.containsKey(DateTime(date.year, date.month, date.day));
  }

  String _getServiceStatus(DateTime date) {
    if (_isHoliday(date)) {
      return 'Holiday: ${_holidays[DateTime(date.year, date.month, date.day)]}';
    }
    if (_isServiceDay(date)) {
      return 'Service Active (6:00 PM - 10:00 PM)';
    }
    return 'No Service Day';
  }

  Color _getDateColor(DateTime date) {
    if (_isHoliday(date)) return Colors.red;
    if (_isServiceDay(date)) return Colors.green;
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
                    _isServiceDay(date) && !_isHoliday(date) 
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
            ] else if (_isServiceDay(date)) ...[
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
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
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
                      const SizedBox(height: 12),
                      _buildScheduleItem('Sunday - Thursday', '6:00 PM - 10:00 PM', Colors.green),
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
