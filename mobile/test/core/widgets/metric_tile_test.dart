import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valet/core/widgets/bento_card.dart';
import 'package:valet/core/widgets/metric_tile.dart';

/// Regression test for the RenderFlex overflow on the owner Financials page.
///
/// MetricTile is used inside a fixed-height BentoCard at 88, 90, 96 and 100 px
/// across the owner, PM and manager dashboards. With real font line-heights the
/// original unconstrained Column exceeded every one of those: the finance cards
/// overflowed by 3px and the labor cards by 11px, which clipped their subtitle.
void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required double height,
    required double width,
    String? subtitle,
    String value = r'$1200',
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: BentoCard(
              height: height,
              child: MetricTile(
                label: 'Est contract / mo',
                value: value,
                subtitle: subtitle,
              ),
            ),
          ),
        ),
      ),
    ));
  }

  group('MetricTile fits its BentoCard', () {
    // Every height the app actually uses, at a narrow (half-width, phone) card.
    for (final height in <double>[88, 90, 96, 100]) {
      testWidgets('height $height with a wrapping subtitle', (tester) async {
        await pumpTile(tester,
            height: height, width: 170, subtitle: 'Hours x hourly rates');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('very long value does not overflow', (tester) async {
      await pumpTile(tester,
          height: 88,
          width: 150,
          value: r'$1,234,567.89',
          subtitle: '34 billable doors across the portfolio');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no subtitle still renders', (tester) async {
      await pumpTile(tester, height: 88, width: 170);
      expect(tester.takeException(), isNull);
      expect(find.text(r'$1200'), findsOneWidget);
    });
  });
}
