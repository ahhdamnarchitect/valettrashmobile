import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'valet_app.dart';

/// Same as main.dart — kept for tooling that targets this file path.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://your-project.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-anon-key',
  );
  runApp(const ValetApp());
}
