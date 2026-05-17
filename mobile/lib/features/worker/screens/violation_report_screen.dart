import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/lottie_feedback.dart';
import '../../../core/widgets/primary_button.dart';

/// Maps to Postgres enum `violation_type`.
final List<Map<String, String>> kViolationDbTypes = [
  {'value': 'too_many_bags', 'label': 'Too Many Bags'},
  {'value': 'untied_bags', 'label': 'Untied Bags'},
  {'value': 'leaking_bags', 'label': 'Leaking Bags'},
  {'value': 'prohibited_items', 'label': 'Prohibited Items'},
  {'value': 'outside_rules', 'label': 'Outside Rules'},
];

class ViolationReportScreen extends StatefulWidget {
  const ViolationReportScreen({super.key});

  @override
  State<ViolationReportScreen> createState() => _ViolationReportScreenState();
}

class _ViolationReportScreenState extends State<ViolationReportScreen> {
  final _unitController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  int _step = 0; // 0=photo, 1=type, 2=details, 3=confirm
  String _selectedViolationType = kViolationDbTypes.first['value']!;
  bool _isLoading = false;
  bool _submitted = false;
  XFile? _image;

  @override
  void dispose() {
    _unitController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource src) async {
    final picked = await _picker.pickImage(source: src, maxWidth: 1600);
    if (picked != null) setState(() => _image = picked);
  }

  Future<String?> _uploadPhoto(String workerId) async {
    final file = _image;
    if (file == null) return null;
    final name =
        '${DateTime.now().millisecondsSinceEpoch}_${file.name}'.replaceAll(' ', '');
    final path = 'workers/$workerId/$name';
    final bytes = await file.readAsBytes();
    await Supabase.instance.client.storage
        .from('violations')
        .uploadBinary(path, bytes,
            fileOptions: const FileOptions(upsert: true));
    return path;
  }

  Future<void> _submitViolation() async {
    final unitNumber = _unitController.text.trim();
    if (unitNumber.isEmpty) {
      _snackError('Please enter a unit number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        _snackError('Sign in required');
        return;
      }

      final assigns = await supabase
          .from('worker_assignments')
          .select('property_id')
          .eq('user_id', currentUser.id)
          .eq('is_active', true);
      final plist = List<Map<String, dynamic>>.from(assigns as List)
          .map((e) => e['property_id']?.toString())
          .whereType<String>()
          .toSet();
      if (plist.isEmpty) {
        _snackError('No property assignment — contact dispatch.');
        return;
      }

      final unitsResp = await supabase
          .from('units')
          .select('id, floors!inner(buildings!inner(property_id))')
          .eq('unit_number', unitNumber);
      final rows = List<Map<String, dynamic>>.from(unitsResp as List);
      String? unitId;
      for (final r in rows) {
        final nested = r['floors'];
        if (nested is! Map) continue;
        final b = nested['buildings'];
        if (b is! Map) continue;
        final pid = b['property_id']?.toString();
        if (pid != null && plist.contains(pid)) {
          unitId = r['id']?.toString();
          break;
        }
      }
      if (unitId == null) {
        _snackError('Unit not found on your assigned properties.');
        return;
      }

      final ru = await supabase
          .from('resident_units')
          .select('user_id')
          .eq('unit_id', unitId)
          .eq('is_active', true)
          .maybeSingle();
      if (ru == null || ru['user_id'] == null) {
        _snackError('No active resident mapped to this unit.');
        return;
      }
      final residentId = ru['user_id'].toString();

      final pickupResp = await supabase
          .from('pickups')
          .select('id')
          .eq('unit_id', unitId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final pickupId =
          pickupResp == null ? null : pickupResp['id']?.toString();

      String? photoPath;
      if (_image != null) {
        photoPath = await _uploadPhoto(currentUser.id);
      }

      await supabase.from('violations').insert({
        if (pickupId != null) 'pickup_id': pickupId,
        'unit_id': unitId,
        'resident_user_id': residentId,
        'worker_user_id': currentUser.id,
        'violation_type': _selectedViolationType,
        'description': _descriptionController.text.trim(),
        if (photoPath != null) 'photo_url': photoPath,
        'status': 'pending',
      });

      setState(() => _submitted = true);

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snackError('Failed to report violation: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.error.withValues(alpha: 0.9),
      content: Text(msg, style: const TextStyle(color: Colors.white)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Report Violation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _submitted ? _buildSuccessView() : _buildStepView(),
    );
  }

  Widget _buildSuccessView() {
    return const LottieSuccessView(
      message: 'Violation Reported',
      subtitle: 'The resident has been notified.',
    );
  }

  Widget _buildStepView() {
    return SafeArea(
      child: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: _buildCurrentStep(),
            ),
          ),
          _buildStepNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Photo', 'Type', 'Details', 'Confirm'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.success
                            : isActive
                                ? AppColors.error
                                : AppColors.surface2,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? AppColors.error
                              : isDone
                                  ? AppColors.success
                                  : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive
                            ? AppColors.error
                            : isDone
                                ? AppColors.success
                                : AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: isDone ? AppColors.success : AppColors.border,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildPhotoStep();
      case 1:
        return _buildTypeStep();
      case 2:
        return _buildDetailsStep();
      default:
        return _buildConfirmStep();
    }
  }

  // Step 0 — Photo
  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Photo',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take or upload a photo of the violation. A photo helps document the issue clearly.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        // Photo preview or placeholder
        if (_image != null)
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined,
                    size: 40, color: AppColors.success),
                const SizedBox(height: 8),
                Text(
                  _image!.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                GlowBadge(
                  label: 'Photo selected',
                  accent: AppColors.success,
                  showDot: true,
                ),
              ],
            ),
          )
        else
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.border, style: BorderStyle.solid),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined,
                    size: 40, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text(
                  'No photo selected',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.worker,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.worker,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Photo is optional but strongly recommended.',
          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Step 1 — Violation type
  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Violation Type',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select the category that best describes the violation.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        ...kViolationDbTypes.map((vt) {
          final isSelected = _selectedViolationType == vt['value'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () =>
                  setState(() => _selectedViolationType = vt['value']!),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.surface1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.error.withValues(alpha: 0.5)
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.error
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.error
                              : AppColors.textMuted,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      vt['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // Step 2 — Details
  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter the unit number and any additional notes.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'UNIT NUMBER',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _unitController,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14),
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            hintText: 'e.g. 104',
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
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
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'NOTES (OPTIONAL)',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the condition...',
            hintStyle:
                const TextStyle(color: AppColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: AppColors.surface2,
            contentPadding: const EdgeInsets.all(16),
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
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // Step 3 — Confirm
  Widget _buildConfirmStep() {
    final typeLabel = kViolationDbTypes
        .firstWhere((t) => t['value'] == _selectedViolationType,
            orElse: () => {'label': _selectedViolationType})['label']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confirm & Submit',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Review the details before submitting.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _summaryRow('Violation Type', typeLabel),
        _summaryRow('Unit Number', _unitController.text.trim().isEmpty
            ? 'Not specified'
            : _unitController.text.trim()),
        _summaryRow(
            'Notes',
            _descriptionController.text.trim().isEmpty
                ? 'None'
                : _descriptionController.text.trim()),
        _summaryRow('Photo', _image != null ? 'Attached' : 'None'),
        const SizedBox(height: 24),
        if (_unitController.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlowBadge(
              label: 'Unit number is required',
              accent: AppColors.error,
              showDot: false,
            ),
          ),
        PrimaryButton(
          label: 'Submit Report',
          onPressed: _isLoading ||
                  _unitController.text.trim().isEmpty
              ? null
              : _submitViolation,
          accent: AppColors.error,
          isLoading: _isLoading,
          icon: Icons.send_outlined,
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step navigation ───────────────────────────────────────────────────────────

  Widget _buildStepNavigation() {
    final isLastStep = _step == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: isLastStep
                ? PrimaryButton(
                    label: 'Submit Report',
                    onPressed: _isLoading ||
                            _unitController.text.trim().isEmpty
                        ? null
                        : _submitViolation,
                    accent: AppColors.error,
                    isLoading: _isLoading,
                  )
                : PrimaryButton(
                    label: _step == 0 && _image == null ? 'Skip Photo' : 'Continue',
                    onPressed: () => setState(() => _step++),
                    accent: AppColors.worker,
                  ),
          ),
        ],
      ),
    );
  }
}
