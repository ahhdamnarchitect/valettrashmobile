import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';

class ResidentSignupScreen extends StatefulWidget {
  const ResidentSignupScreen({super.key});

  @override
  State<ResidentSignupScreen> createState() => _ResidentSignupScreenState();
}

class _ResidentSignupScreenState extends State<ResidentSignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _unitController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String? _selectedPropertyId;
  bool _isLoading = false;
  bool _propertiesLoading = true;
  bool _obscurePassword = true;
  String? _error;
  List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _unitController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    try {
      final properties = await Supabase.instance.client
          .from('properties')
          .select('id, name')
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _properties = List<Map<String, dynamic>>.from(properties as List);
          _propertiesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _propertiesLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _verifyInviteCode() async {
    if (_selectedPropertyId == null ||
        _unitController.text.trim().isEmpty ||
        _inviteCodeController.text.trim().isEmpty) return null;
    try {
      final result = await Supabase.instance.client.rpc(
        'verify_invite_code',
        params: {
          'p_invite_code': _inviteCodeController.text.trim().toUpperCase(),
          'p_property_id': _selectedPropertyId,
          'p_unit_number': _unitController.text.trim(),
        },
      );
      if (result is! List || result.isEmpty) return null;
      final row = result.first;
      return row is Map<String, dynamic>
          ? row
          : Map<String, dynamic>.from(row as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _signUp() async {
    final allFilled = _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        _selectedPropertyId != null &&
        _unitController.text.trim().isNotEmpty &&
        _inviteCodeController.text.trim().isNotEmpty;
    if (!allFilled) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passwordController.text.trim().length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final verification = await _verifyInviteCode();
      if (verification == null || verification['is_valid'] != true) {
        setState(() => _error = verification == null
            ? 'Unable to validate invite code.'
            : (verification['message']?.toString() ?? 'Invalid invite code.'));
        return;
      }

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (authResponse.user == null) {
        setState(() => _error = 'Account creation failed. Please try again.');
        return;
      }

      final userId = authResponse.user!.id;
      final client = Supabase.instance.client;

      await client.from('users').insert({
        'id': userId,
        'email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'role': 'resident',
      });

      await client.rpc('claim_invite_code', params: {
        'p_invite_id': verification['invite_id'],
        'p_user_id': userId,
      });

      await client.from('resident_units').insert({
        'user_id': userId,
        'unit_id': verification['unit_id'],
        'property_id': verification['property_id'],
        'move_in_date': DateTime.now().toIso8601String().split('T').first,
        'is_active': true,
      });

      if (!mounted) return;
      if (client.auth.currentSession != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('User already registered')) {
        msg = 'Email already registered. Please sign in.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Resident Sign Up',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.resident.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.resident.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.resident.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.vpn_key_outlined,
                        color: AppColors.resident, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Code Required',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Get your invite code from your property manager.',
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
            _label('YOUR INFORMATION'),
            const SizedBox(height: 10),
            _field(_firstNameController, 'First Name'),
            const SizedBox(height: 12),
            _field(_lastNameController, 'Last Name'),
            const SizedBox(height: 12),
            _field(_emailController, 'Email',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_passwordController, 'Password',
                obscure: _obscurePassword,
                onToggleObscure: () =>
                    setState(() => _obscurePassword = !_obscurePassword)),

            const SizedBox(height: 24),
            _label('PROPERTY & UNIT'),
            const SizedBox(height: 10),

            // Property dropdown
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _propertiesLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Row(children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Loading properties…',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ]),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPropertyId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface1,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        iconEnabledColor: AppColors.textMuted,
                        hint: const Text('Select property',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 14)),
                        items: _properties
                            .map((p) => DropdownMenuItem(
                                  value: p['id'].toString(),
                                  child: Text(p['name'].toString()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedPropertyId = v),
                      ),
                    ),
            ),

            const SizedBox(height: 12),
            _field(_unitController, 'Unit Number',
                hint: 'e.g. 104'),

            const SizedBox(height: 24),
            _label('INVITE CODE'),
            const SizedBox(height: 10),
            _field(_inviteCodeController, 'Invite Code',
                hint: 'e.g. WELCOME104', caps: true),

            const SizedBox(height: 24),

            if (_error != null) ...[
              GlowBadge(
                  label: _error!, accent: AppColors.error, showDot: false),
              const SizedBox(height: 16),
            ],

            PrimaryButton(
              label: _isLoading ? 'Creating Account…' : 'Create Account',
              accent: AppColors.resident,
              onPressed: _isLoading ? null : _signUp,
              isLoading: _isLoading,
              icon: Icons.person_add_outlined,
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Already have an account? Sign In',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? hint,
    bool caps = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      ),
    );
  }
}
