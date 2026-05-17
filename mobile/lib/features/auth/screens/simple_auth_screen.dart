import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../manager/screens/manager_dashboard_screen.dart';
import '../../manager/screens/property_manager_dashboard_new.dart';
import '../../owner/screens/owner_dashboard_screen.dart';
import '../../test/screens/test_connection_screen.dart';
import '../../worker/screens/worker_dashboard_screen.dart';
import 'change_password_screen.dart';
import 'resident_signup_screen.dart';

class SimpleAuthScreen extends StatefulWidget {
  const SimpleAuthScreen({super.key});

  @override
  State<SimpleAuthScreen> createState() => _SimpleAuthScreenState();
}

// Wraps a widget so it only plays its animation once on first mount.
class _OnceAnimate extends StatefulWidget {
  const _OnceAnimate({required this.child, required this.delay});
  final Widget child;
  final Duration delay;

  @override
  State<_OnceAnimate> createState() => _OnceAnimateState();
}

class _OnceAnimateState extends State<_OnceAnimate> {
  @override
  Widget build(BuildContext context) {
    return widget.child
        .animate(delay: widget.delay)
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
  }
}

class _SimpleAuthScreenState extends State<SimpleAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // ── Business logic — unchanged ──────────────────────────────────────

  Future<void> _ensureUserProfileExists() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final existingProfile = await supabase
          .from('users')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (existingProfile == null) {
        await supabase.from('users').insert({
          'id': currentUser.id,
          'email': currentUser.email,
          'first_name': _firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : 'New',
          'last_name': _lastNameController.text.trim().isNotEmpty
              ? _lastNameController.text.trim()
              : 'User',
          'role': 'resident',
        });
      }
    } catch (e) {
      debugPrint('Failed to ensure user profile exists: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final session = supabase.auth.currentSession;
        if (session != null) {
          await _ensureUserProfileExists();
          setState(() => _success = 'Signed in successfully!');
        } else {
          setState(() => _error = 'Sign in completed but no session created');
        }
      } else {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'role': 'resident',
          },
        );
        if (response.user != null) {
          await _ensureUserProfileExists();
          setState(() {
            _success = response.user?.emailConfirmedAt != null
                ? 'Account created successfully!'
                : 'Account created! Please check your email for confirmation.';
            if (response.user?.emailConfirmedAt == null) _isLogin = true;
          });
        } else {
          setState(() => _error = 'Account creation failed. Please try again.');
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Invalid login credentials')) msg = 'Invalid email or password';
      else if (msg.contains('User already registered')) msg = 'Email already registered. Please sign in.';
      else if (msg.contains('Email not confirmed')) msg = 'Please confirm your email before signing in.';
      setState(() => _error = msg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _success = null;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _OnceAnimate(delay: 0.ms, child: _buildWordmark()),
                const SizedBox(height: 48),
                _OnceAnimate(delay: 60.ms, child: _buildModeHeading()),
                const SizedBox(height: 28),
                if (!_isLogin) ..._buildNameFields(),
                _OnceAnimate(delay: 120.ms, child: _buildEmailField()),
                const SizedBox(height: 12),
                _OnceAnimate(delay: 180.ms, child: _buildPasswordField()),
                if (_isLogin) _buildForgotPasswordLink(),
                const SizedBox(height: 16),
                if (_error != null) _buildErrorBadge(),
                if (_success != null) _buildSuccessBadge(),
                const SizedBox(height: 4),
                _OnceAnimate(
                  delay: 240.ms,
                  child: PrimaryButton(
                    label: _isLogin ? 'Sign In' : 'Sign Up',
                    onPressed: _isLoading ? null : _submit,
                    accent: AppColors.resident,
                    isLoading: _isLoading,
                  ),
                ),
                const SizedBox(height: 16),
                _OnceAnimate(
                  delay: 300.ms,
                  child: TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already have an account? Sign in',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _OnceAnimate(delay: 360.ms, child: _buildResidentSignupButton()),
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  _buildDebugSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Column(
      children: [
        Text(
          'RELAXED LIVING',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.16 * 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Valet Service',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.04 * 28,
          ),
        ),
      ],
    );
  }

  Widget _buildModeHeading() {
    return Text(
      _isLogin ? 'Sign In' : 'Create Account',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }

  List<Widget> _buildNameFields() {
    return [
      _darkField(
        controller: _firstNameController,
        label: 'First Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      _darkField(
        controller: _lastNameController,
        label: 'Last Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildEmailField() {
    return _darkField(
      controller: _emailController,
      label: 'Email',
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _darkField(
      controller: _passwordController,
      label: 'Password',
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textMuted,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (v.length < 6) return 'At least 6 characters';
        return null;
      },
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.resident, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Forgot password?',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlowBadge(
        label: _error!,
        accent: AppColors.error,
        showDot: false,
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlowBadge(
        label: _success!,
        accent: AppColors.success,
        showDot: false,
      ),
    );
  }

  Widget _buildResidentSignupButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResidentSignupScreen()),
      ),
      icon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppColors.textSecondary),
      label: const Text(
        'Resident Sign Up (Invite Code)',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDebugSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppColors.border),
        const SizedBox(height: 8),
        Text(
          'DEBUG NAVIGATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.14 * 9,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ...[
          ('Property Manager Dashboard', const PropertyManagerDashboardNewScreen()),
          ('Worker Dashboard', const WorkerDashboardScreen()),
          ('Operations Manager Dashboard', const ManagerDashboardScreen()),
          ('Owner Dashboard', const OwnerDashboardScreen()),
          ('Test Connection', const TestConnectionScreen()),
        ].map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => entry.$2),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(entry.$1, style: const TextStyle(fontSize: 12)),
              ),
            )),
      ],
    );
  }
}
