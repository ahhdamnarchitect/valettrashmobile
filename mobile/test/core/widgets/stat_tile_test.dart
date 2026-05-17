import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/stat_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Row(children: [child])),
      );

  group('StatTile', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: '12', label: 'Streak'),
      ));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget); // label is uppercased
    });

    testWidgets('uses custom value color when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: '3', label: 'Violations', valueColor: AppColors.error),
      ));
      final text = tester.widget<Text>(find.text('3'));
      expect(text.style?.color, AppColors.error);
    });

    testWidgets('uses textPrimary when no valueColor given', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: 'A+', label: 'Rating'),
      ));
      final text = tester.widget<Text>(find.text('A+'));
      expect(text.style?.color, AppColors.textPrimary);
    });
  });
}
