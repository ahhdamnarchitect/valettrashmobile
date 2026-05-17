import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mobile/features/auth/screens/simple_auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://test-project.supabase.co',
      anonKey: 'test-anon-key-for-widget-tests',
    );
  });

  testWidgets('SimpleAuthScreen shows sign in heading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SimpleAuthScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsWidgets);
  });
}
