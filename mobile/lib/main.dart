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
    // supabase_flutter v2 dropped authCallbackUrlHostname and detects the
    // com.relaxedliving.valet://login-callback deep link automatically via
    // app_links, using the scheme declared in the iOS/Android manifests. The
    // redirect must still be whitelisted under Auth -> URL Configuration.
  );

  runApp(const ValetApp());
}
