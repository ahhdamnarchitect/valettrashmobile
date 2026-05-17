import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/primary_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        )),
      );

  group('PrimaryButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Sign In',
          onPressed: () {},
          accent: AppColors.resident,
        ),
      ));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Tap me',
          onPressed: () => called = true,
          accent: AppColors.resident,
        ),
      ));
      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets('shows CircularProgressIndicator when isLoading', (tester) async {
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Loading',
          onPressed: () {},
          accent: AppColors.resident,
          isLoading: true,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Disabled',
          onPressed: null,
          accent: AppColors.resident,
        ),
      ));
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(called, isFalse);
    });
  });
}
