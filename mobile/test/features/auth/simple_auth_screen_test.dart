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

    testWidgets('OAuth buttons follow kOAuthProvidersConfigured', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(settle);
      // Apple / Google are hidden until the providers are actually configured in
      // Supabase, so nobody taps a button that can only fail. This asserts the flag
      // and the UI agree, in whichever state the flag is left.
      final matcher =
          kOAuthProvidersConfigured ? findsOneWidget : findsNothing;
      expect(find.text('Apple'), matcher);
      expect(find.text('Google'), matcher);
      expect(find.text('or continue with'), matcher);
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
