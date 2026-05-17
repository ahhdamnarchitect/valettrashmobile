import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/auth/screens/change_password_screen.dart';
import 'features/auth/screens/simple_auth_screen.dart';
import 'features/manager/screens/manager_dashboard_screen.dart';
import 'features/manager/screens/property_manager_dashboard_new.dart';
import 'features/owner/screens/owner_dashboard_screen.dart';
import 'features/resident/screens/resident_dashboard_screen.dart';
import 'features/test/screens/test_connection_screen.dart';
import 'features/worker/screens/worker_dashboard_screen.dart';

class ValetApp extends StatelessWidget {
  const ValetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relaxed Living Valet',
      theme: AppTheme.dark,
      home: const AuthGate(),
      routes: {
        '/test': (context) => const TestConnectionScreen(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ChangePasswordScreen(isRecovery: true);
        }
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const SimpleAuthScreen();
        }
        return const RoleHome();
      },
    );
  }
}

class RoleHome extends StatefulWidget {
  const RoleHome({super.key});

  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  String? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _role = 'resident';
      });
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      setState(() {
        _role = row?['role'] as String? ?? 'resident';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _role = 'resident';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    switch (_role) {
      case 'driver':
        return const WorkerDashboardScreen();
      case 'property_manager':
        return Theme(
          data: AppTheme.light,
          child: const PropertyManagerDashboardNewScreen(),
        );
      case 'operations_manager':
        return const ManagerDashboardScreen();
      case 'owner':
        return Theme(
          data: AppTheme.light,
          child: const OwnerDashboardScreen(),
        );
      case 'super_admin':
        return Theme(
          data: AppTheme.light,
          child: const AdminDashboardScreen(),
        );
      case 'resident':
      default:
        return const ResidentDashboardScreen();
    }
  }
}
