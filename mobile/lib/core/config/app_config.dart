/// Compile-time Supabase configuration.
///
/// Values are baked in at build time via `--dart-define-from-file`, not read
/// from a bundled `.env` asset. See `mobile/README.md` → "Configuration".
///
///     flutter run   --dart-define-from-file=dart_define.json -d chrome
///     flutter build web --dart-define-from-file=dart_define.json
///
/// Note: these are **not** secrets. The Supabase anon/publishable key is
/// designed to ship inside the client, and anyone can extract it from a built
/// app. Row Level Security is what actually protects the data — never put the
/// `service_role` key or any Stripe secret here. Those belong in Supabase Edge
/// Function secrets (see `brain/stripe_setup.md`).
class AppConfig {
  const AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Throws a readable error instead of letting Supabase fail with an opaque
  /// one when the build forgot `--dart-define-from-file`.
  static void assertConfigured() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabaseAnonKey.isEmpty) 'SUPABASE_ANON_KEY',
    ];
    if (missing.isEmpty) return;
    throw StateError(
      'Missing compile-time config: ${missing.join(', ')}.\n'
      'Build with: flutter run --dart-define-from-file=dart_define.json\n'
      'Copy dart_define.example.json to dart_define.json and fill in the values '
      '(Supabase Dashboard → Settings → API).',
    );
  }
}
