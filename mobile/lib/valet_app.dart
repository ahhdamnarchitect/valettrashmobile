import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/user_profile.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCheckoutToast());
  }

  void _maybeShowCheckoutToast() {
    final checkout = Uri.base.queryParameters['checkout'];
    if (checkout == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          checkout == 'success'
              ? 'Payment received. Credits appear after Stripe confirms (usually a few seconds).'
              : 'Checkout canceled. No charge was made.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
        return RoleHome(
          key: ValueKey(session.user.id),
        );
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
        _role = null;
      });
      return;
    }
    setState(() => _loading = true);
    final role = await fetchUserRole(uid);
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading your account…',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_role == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'We could not load your profile yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'If you just signed up, tap Retry. Otherwise sign out and sign in again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
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
      case 'super_admin':
        return Theme(
          data: AppTheme.light,
          child: const OwnerDashboardScreen(),
        );
      case 'resident':
      default:
        return const ResidentDashboardScreen();
    }
  }
}
