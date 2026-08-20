import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valet/features/auth/screens/simple_auth_screen.dart';

void main() {
  // flutter_animate restarts animations on setState; pump 2s drains all timers.
  const settle = Duration(seconds: 2);

  Widget wrap() => const MaterialApp(home: SimpleAuthScreen());

  group('SimpleAuthScreen', () {
    testWidgets('renders Welcome Back heading', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('renders email and password fields only (no sign-up toggle)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('renders Apple and Google OAuth buttons', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('renders sign up options', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      // The single "Sign up" link this test used to look for was replaced by
      // separate Resident / Staff signup buttons, which take different invite
      // flows. The test was never updated, so it had been red against main.
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Resident'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
    });

    testWidgets('renders forgot password link', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      expect(find.text('Forgot password?'), findsOneWidget);
    });
  });
}
