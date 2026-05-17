import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lottie_feedback.dart';
import '../../../core/widgets/primary_button.dart';

const _subjects = [
  'General Question',
  'Billing Inquiry',
  'Service Feedback',
  'Scheduling Issue',
  'Property Concern',
  'Other',
];

class ResidentConcernsScreen extends StatefulWidget {
  const ResidentConcernsScreen({super.key});

  @override
  State<ResidentConcernsScreen> createState() => _ResidentConcernsScreenState();
}

class _ResidentConcernsScreenState extends State<ResidentConcernsScreen> {
  String _subject = _subjects.first;
  final _messageController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your question or concern.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      String? propertyId;
      try {
        final unitRow = await client
            .from('resident_units')
            .select('property_id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();
        propertyId = unitRow?['property_id']?.toString();
      } catch (_) {}

      await client.from('resident_concerns').insert({
        'resident_user_id': uid,
        'property_id': propertyId,
        'subject': _subject,
        'message': message,
      });

      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          'Questions & Concerns',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _submitted
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LottieSuccessView(
                      message: 'Message Sent',
                      subtitle:
                          'A team member will follow up with you shortly.',
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.resident,
                        side: const BorderSide(color: AppColors.resident),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('TOPIC'),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _subject,
                        isExpanded: true,
                        dropdownColor: AppColors.surface1,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        iconEnabledColor: AppColors.textMuted,
                        items: _subjects
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _subject = v);
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  _sectionLabel('MESSAGE'),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _messageController,
                    maxLines: 6,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Describe your question or concern in detail…',
                      hintStyle: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface1,
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
                        borderSide: const BorderSide(
                            color: AppColors.resident, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  const SizedBox(height: 32),

                  PrimaryButton(
                    label: _submitting ? 'Sending…' : 'Submit',
                    accent: AppColors.resident,
                    onPressed: _submitting ? null : _submit,
                    icon: Icons.send_outlined,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      );
}
