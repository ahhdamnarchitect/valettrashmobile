import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  /// [isRecovery] = true when launched from the passwordRecovery auth event
  /// (user clicked link in email). Shows "Set New Password" form directly.
  /// [isRecovery] = false (default) when launched from a profile tab — shows
  /// "Send reset email" flow first.
  final bool isRecovery;

  const ChangePasswordScreen({super.key, this.isRecovery = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _emailSent = false;
  String? _error;
  String? _success;

  String get _email =>
      Supabase.instance.client.auth.currentUser?.email ?? '';

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_email.isEmpty) {
      setState(() => _error = 'No email address found for this account.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // On mobile, redirect to the app's custom URL scheme so the deep link
      // returns to the app instead of the browser.
      final redirectTo = kIsWeb ? null : 'com.relaxedliving.valet://login-callback';
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _email,
        redirectTo: redirectTo,
      );
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to send email: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    final pass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pass));
      if (mounted) {
        setState(() => _success = 'Password updated successfully!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecoveryMode = widget.isRecovery;

    return Scaffold(
      backgroundColor: isRecoveryMode ? Colors.white : AppColors.background,
      appBar: AppBar(
        backgroundColor:
            isRecoveryMode ? Colors.white : AppColors.background,
        foregroundColor:
            isRecoveryMode ? Colors.black87 : AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          isRecoveryMode ? 'Set New Password' : 'Change Password',
          style: TextStyle(
            color: isRecoveryMode ? Colors.black87 : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        leading: isRecoveryMode
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    size: 18, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: isRecoveryMode
            ? _buildSetPasswordForm()
            : (_emailSent ? _buildEmailSentState() : _buildSendEmailState()),
      ),
    );
  }

  // ── State 1: Send reset email ─────────────────────────────────────────────

  Widget _buildSendEmailState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_reset_outlined,
                    color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Secure Password Reset',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'We\'ll email you a secure link to set your new password.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'RESET LINK WILL BE SENT TO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined,
                  color: AppColors.textMuted, size: 18),
              const SizedBox(width: 10),
              Text(
                _email,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (_error != null) ...[
          GlowBadge(label: _error!, accent: AppColors.error, showDot: false),
          const SizedBox(height: 16),
        ],
        PrimaryButton(
          label: _loading ? 'Sending…' : 'Send Reset Email',
          accent: AppColors.info,
          onPressed: _loading ? null : _sendResetEmail,
          isLoading: _loading,
          icon: Icons.send_outlined,
        ),
      ],
    );
  }

  // ── State 2: Email sent confirmation ──────────────────────────────────────

  Widget _buildEmailSentState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Check Your Email',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A reset link has been sent to\n$_email\n\nClick the link to set your new password.',
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _loading ? null : _sendResetEmail,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Resend Email',
              style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  // ── State 3: Set new password (recovery mode) ─────────────────────────────

  Widget _buildSetPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified_user_outlined,
                    color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Identity verified via email link. Enter your new password below.',
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 13,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildPasswordField(
          controller: _newPassCtrl,
          label: 'New Password',
          obscure: _obscureNew,
          onToggle: () => setState(() => _obscureNew = !_obscureNew),
          isLight: true,
        ),
        const SizedBox(height: 12),
        _buildPasswordField(
          controller: _confirmPassCtrl,
          label: 'Confirm New Password',
          obscure: _obscureConfirm,
          onToggle: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          isLight: true,
        ),
        const SizedBox(height: 8),
        const Text(
          'Minimum 8 characters',
          style: TextStyle(color: Colors.black38, fontSize: 11),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(_error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],
        if (_success != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(_success!,
                style:
                    TextStyle(color: Colors.green.shade700, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton(
          onPressed: _loading || _success != null ? null : _updatePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Update Password',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    bool isLight = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
          color: isLight ? Colors.black87 : AppColors.textPrimary,
          fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isLight ? Colors.black45 : AppColors.textMuted,
            fontSize: 13),
        filled: true,
        fillColor: isLight ? Colors.grey.shade50 : AppColors.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isLight ? Colors.grey.shade300 : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: isLight ? Colors.grey.shade300 : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: isLight ? Colors.black38 : AppColors.textMuted,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
