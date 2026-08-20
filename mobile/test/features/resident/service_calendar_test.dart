import 'package:flutter_test/flutter_test.dart';
import 'package:valet/features/resident/screens/resident_service_calendar_screen.dart';

/// Regression tests for the service calendar's date rules.
///
/// Before this, the screen hardcoded floating federal holidays to fixed dates
/// (MLK Jan 15, Memorial May 27, Labor Sep 2, Thanksgiving Nov 28), so all four were
/// wrong in any year but the one they were typed in. It also treated Sunday as a
/// no-service day while its own legend advertised "Sunday - Thursday", and it showed
/// a hardcoded "6:00 PM - 10:00 PM" window to every resident regardless of property.
void main() {
  group('floating federal holidays', () {
    // Dates verified against the official OPM federal holiday schedule.
    const expected = <int, Map<String, String>>{
      2026: {
        'Martin Luther King Jr. Day': '2026-01-19',
        'Memorial Day': '2026-05-25',
        'Labor Day': '2026-09-07',
        'Thanksgiving Day': '2026-11-26',
      },
      2027: {
        'Martin Luther King Jr. Day': '2027-01-18',
        'Memorial Day': '2027-05-31',
        'Labor Day': '2027-09-06',
        'Thanksgiving Day': '2027-11-25',
      },
      2028: {
        'Martin Luther King Jr. Day': '2028-01-17',
        'Memorial Day': '2028-05-29',
        'Labor Day': '2028-09-04',
        'Thanksgiving Day': '2028-11-23',
      },
    };

    expected.forEach((year, holidays) {
      test('are correct in $year', () {
        final map = ServiceSchedule.federalHolidays(year);
        holidays.forEach((name, iso) {
          final matches = map.entries.where((e) => e.value == name).toList();
          expect(matches, hasLength(1), reason: '$name missing in $year');
          final d = matches.single.key;
          final actual = '${d.year}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
          expect(actual, iso, reason: '$name in $year');
        });
      });
    });

    test('fixed-date holidays stay fixed', () {
      final map = ServiceSchedule.federalHolidays(2026);
      expect(map[DateTime(2026, 1, 1)], "New Year's Day");
      expect(map[DateTime(2026, 7, 4)], 'Independence Day');
      expect(map[DateTime(2026, 11, 11)], 'Veterans Day');
      expect(map[DateTime(2026, 12, 25)], 'Christmas Day');
    });
  });

  group('service days are Sunday through Thursday', () {
    final sunday = DateTime(2026, 8, 16); // a Sunday
    for (var i = 0; i < 7; i++) {
      final day = sunday.add(Duration(days: i));
      final offDay =
          day.weekday == DateTime.friday || day.weekday == DateTime.saturday;
      test('weekday ${day.weekday} is ${offDay ? "off" : "a service day"}', () {
        expect(ServiceSchedule.isServiceDay(day), !offDay);
      });
    }

    test('Sunday is a service day', () {
      // The old `weekday <= 4` check silently excluded it.
      expect(ServiceSchedule.isServiceDay(DateTime(2026, 8, 16)), isTrue);
    });
  });

  group('service window formatting', () {
    test('renders the per-property window, not a hardcoded one', () {
      expect(ServiceSchedule.formatTime('18:00:00'), '6:00 PM');
      expect(ServiceSchedule.formatTime('17:30:00'), '5:30 PM'); // Oakwood Heights
      expect(ServiceSchedule.formatTime('21:30:00'), '9:30 PM');
      expect(ServiceSchedule.formatTime('00:15:00'), '12:15 AM');
      expect(ServiceSchedule.formatTime('12:00:00'), '12:00 PM');
    });

    test('degrades instead of throwing on bad input', () {
      expect(ServiceSchedule.formatTime(null), '--');
      expect(ServiceSchedule.formatTime(''), '--');
      expect(ServiceSchedule.formatTime('garbage'), '--');
    });
  });
}
