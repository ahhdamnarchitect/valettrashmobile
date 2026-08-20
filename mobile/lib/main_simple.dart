import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'valet_app.dart';

/// Same as main.dart — kept for tooling that targets this file path.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertConfigured();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const ValetApp());
}
