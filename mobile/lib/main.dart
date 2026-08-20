import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'valet_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertConfigured();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    // Handles the com.relaxedliving.valet://login-callback deep link
    // that Supabase sends back after password reset on mobile.
    authCallbackUrlHostname: 'login-callback',
  );

  runApp(const ValetApp());
}
