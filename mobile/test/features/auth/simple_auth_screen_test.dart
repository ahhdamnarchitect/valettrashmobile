import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/screens/simple_auth_screen.dart';

void main() {
  // flutter_animate restarts animations on setState; pump 2s drains all timers.
  const settle = Duration(seconds: 2);

  Widget wrap() => const MaterialApp(home: SimpleAuthScreen());

  group('SimpleAuthScreen', () {
    testWidgets('renders sign in heading', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows first name and last name fields in sign up mode', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump(settle);

      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('toggles to sign up mode and back', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump(settle);
      expect(find.text('Sign Up'), findsWidgets);

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pump(settle);
      expect(find.text('Sign In'), findsWidgets);
    });
  });
}
