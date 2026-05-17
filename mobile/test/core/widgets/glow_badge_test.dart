import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/glow_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Center(child: child)),
      );

  group('GlowBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Active', accent: AppColors.resident),
      ));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows glow dot by default', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Active', accent: AppColors.resident),
      ));
      // Container with circular BoxDecoration used for the dot
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dots = containers.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(dots, isNotEmpty);
    });

    testWidgets('hides dot when showDot is false', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Done', accent: AppColors.resident, showDot: false),
      ));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dots = containers.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(dots, isEmpty);
    });

    testWidgets('uses accent color for text', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'On Route', accent: AppColors.worker),
      ));
      final textWidget = tester.widget<Text>(find.text('On Route'));
      expect(textWidget.style?.color, AppColors.worker);
    });
  });
}
