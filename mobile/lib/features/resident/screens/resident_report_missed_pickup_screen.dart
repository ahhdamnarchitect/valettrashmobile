import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lottie_feedback.dart';
import '../../../core/widgets/primary_button.dart';

class ResidentReportMissedPickupScreen extends StatefulWidget {
  const ResidentReportMissedPickupScreen({super.key});

  @override
  State<ResidentReportMissedPickupScreen> createState() =>
      _ResidentReportMissedPickupScreenState();
}

class _ResidentReportMissedPickupScreenState
    extends State<ResidentReportMissedPickupScreen> {
  final _notesController = TextEditingController();
  Uint8List? _photoBytes;
  String? _photoName;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoName = file.name;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      String? photoUrl;

      // Upload photo if selected
      if (_photoBytes != null && _photoName != null) {
        try {
          final ext = _photoName!.split('.').last;
          final path =
              'missed_pickups/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
          await client.storage
              .from('violations')
              .uploadBinary(path, _photoBytes!);
          final url =
              client.storage.from('violations').getPublicUrl(path);
          photoUrl = url;
        } catch (_) {
          // Storage upload failed — continue without photo
        }
      }

      // Find today's pickup for this resident if possible
      String? pickupId;
      try {
        final now = DateTime.now();
        final todayStart =
            DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

        // Get resident's unit
        final unitRow = await client
            .from('resident_units')
            .select('unit_id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();

        if (unitRow != null) {
          final unitId = unitRow['unit_id']?.toString();
          if (unitId != null) {
            final pickup = await client
                .from('pickups')
                .select('id')
                .eq('unit_id', unitId)
                .gte('created_at', todayStart)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            pickupId = pickup?['id']?.toString();
          }
        }
      } catch (_) {}

      // Build insert data — include notes and photo_url only if columns exist
      final insertData = <String, dynamic>{
        'resident_user_id': uid,
        'status': 'pending',
        'is_free': true,
        'requested_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (pickupId != null) insertData['pickup_id'] = pickupId;

      // Try inserting with notes/photo columns first; fall back if they don't exist
      try {
        final withExtras = Map<String, dynamic>.from(insertData);
        if (_notesController.text.trim().isNotEmpty) {
          withExtras['notes'] = _notesController.text.trim();
        }
        if (photoUrl != null) withExtras['photo_url'] = photoUrl;
        await client.from('missed_pickup_requests').insert(withExtras);
      } catch (e) {
        if (e.toString().contains('notes') ||
            e.toString().contains('photo_url') ||
            e.toString().contains('column')) {
          // Columns don't exist yet — insert without them
          await client.from('missed_pickup_requests').insert(insertData);
        } else {
          rethrow;
        }
      }

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
          'Report Missed Pickup',
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
                      message: 'Report Submitted',
                      subtitle:
                          'We\'ll follow up on your missed pickup as soon as possible.',
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
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.resident.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.resident.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.resident, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Were your bags set out but not collected? Submit this report and a driver will follow up.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _sectionLabel('DESCRIPTION'),
                  const SizedBox(height: 10),

                  // Notes field
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'Describe what happened — e.g. "Bags were set out by 7 PM but not picked up"',
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

                  const SizedBox(height: 24),

                  _sectionLabel('PHOTO EVIDENCE (OPTIONAL)'),
                  const SizedBox(height: 10),

                  // Photo picker
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      height: _photoBytes != null ? null : 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _photoBytes != null
                              ? AppColors.resident.withValues(alpha: 0.4)
                              : AppColors.border,
                          style: _photoBytes != null
                              ? BorderStyle.solid
                              : BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _photoBytes != null
                          ? Stack(
                              children: [
                                Image.memory(
                                  _photoBytes!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _photoBytes = null;
                                      _photoName = null;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.background
                                            .withValues(alpha: 0.8),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: AppColors.textPrimary,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppColors.textMuted,
                                  size: 32,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Tap to add a photo',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Show your bags were set out',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  PrimaryButton(
                    label: _submitting ? 'Submitting…' : 'Submit Report',
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
