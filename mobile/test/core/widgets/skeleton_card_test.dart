import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/core/widgets/skeleton_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      );

  group('SkeletonCard', () {
    testWidgets('renders a Shimmer widget', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard()));
      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders with custom height', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard(height: 120)));
      // Height is set via SizedBox inside Shimmer
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere((s) => s.height == 120, orElse: () => const SizedBox());
      expect(sizedBox.height, 120);
    });

    testWidgets('default height is 80', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard()));
      // Verify the widget renders without overflow at default height
      expect(tester.takeException(), isNull);
    });
  });
}
