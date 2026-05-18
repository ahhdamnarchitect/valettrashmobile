import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
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

class _SimpleAuthScreenState extends State<SimpleAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Invalid login credentials')) msg = 'Invalid email or password';
      else if (msg.contains('Email not confirmed')) msg = 'Please confirm your email before signing in.';
      if (!mounted) return;
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null) throw Exception('Google sign-in failed: no ID token');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Google sign-in failed. Configure Google OAuth in Supabase to enable.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Apple sign-in failed: no identity token');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: Provider.apple,
        idToken: idToken,
        nonce: credential.authorizationCode,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Apple sign-in requires an Apple Developer account to be configured.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                _buildLogo(),
                const SizedBox(height: 36),
                _buildWelcomeText(),
                const SizedBox(height: 28),
                _buildEmailField(),
                const SizedBox(height: 12),
                _buildPasswordField(),
                _buildForgotPasswordLink(),
                const SizedBox(height: 8),
                if (_error != null) ...[
                  GlowBadge(
                    label: _error!,
                    accent: AppColors.error,
                    showDot: false,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSignInButton(),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildOAuthButtons(),
                const SizedBox(height: 28),
                _buildSignUpLink(),
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

  Widget _buildLogo() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 80,
            height: 80,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RELAXED LIVING',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'VALET',
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
            color: AppColors.rlvBlue,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildWelcomeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to continue',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ).animate(delay: 60.ms).fadeIn(duration: 250.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildEmailField() {
    return _styledField(
      controller: _emailController,
      label: 'Email address',
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    ).animate(delay: 120.ms).fadeIn(duration: 250.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildPasswordField() {
    return _styledField(
      controller: _passwordController,
      label: 'Password',
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (v.length < 6) return 'At least 6 characters';
        return null;
      },
    ).animate(delay: 180.ms).fadeIn(duration: 250.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _styledField({
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
      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface1,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: AppColors.rlvBlue, width: 1.5),
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
        child: Text(
          'Forgot password?',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.rlvBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.rlvBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.rlvBlue.withValues(alpha: 0.5),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Sign In',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    ).animate(delay: 240.ms).fadeIn(duration: 250.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    ).animate(delay: 300.ms).fadeIn(duration: 250.ms);
  }

  Widget _buildOAuthButtons() {
    return Row(
      children: [
        Expanded(
          child: _oauthButton(
            onPressed: _isLoading ? null : _signInWithApple,
            icon: const Icon(Icons.apple, size: 22, color: Colors.white),
            label: 'Apple',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _oauthButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: Text(
              'G',
              style: GoogleFonts.montserrat(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            label: 'Google',
          ),
        ),
      ],
    ).animate(delay: 360.ms).fadeIn(duration: 250.ms);
  }

  Widget _oauthButton({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface1,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ResidentSignupScreen()),
          ),
          child: Text(
            'Sign up',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.rlvBlue,
            ),
          ),
        ),
      ],
    ).animate(delay: 420.ms).fadeIn(duration: 250.ms);
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
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...[
          ('Property Manager Dashboard', const PropertyManagerDashboardNewScreen()),
          ('Worker Dashboard', const WorkerDashboardScreen()),
          ('Operations Manager Dashboard', const ManagerDashboardScreen()),
          ('Owner Dashboard', const OwnerDashboardScreen()),
          ('Test Connection', const TestConnectionScreen()),
        ].map(
          (entry) => Padding(
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                entry.$1,
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
