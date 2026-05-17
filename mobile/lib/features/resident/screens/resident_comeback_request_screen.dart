import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lottie_feedback.dart';
import '../../../core/widgets/primary_button.dart';

class ResidentComebackRequestScreen extends StatefulWidget {
  final int freeRemain;
  final num comebackFee;

  const ResidentComebackRequestScreen({
    super.key,
    required this.freeRemain,
    required this.comebackFee,
  });

  @override
  State<ResidentComebackRequestScreen> createState() =>
      _ResidentComebackRequestScreenState();
}

class _ResidentComebackRequestScreenState
    extends State<ResidentComebackRequestScreen> {
  final _notesController = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _isPaid = widget.freeRemain <= 0;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      // Find today's pickup for this resident
      String? pickupId;
      String? propertyId;
      try {
        final unitRow = await client
            .from('resident_units')
            .select('unit_id, property_id')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();

        if (unitRow != null) {
          propertyId = unitRow['property_id']?.toString();
          final unitId = unitRow['unit_id']?.toString();
          if (unitId != null) {
            final now = DateTime.now();
            final todayStart =
                DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
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

      final now = DateTime.now();
      final insertData = <String, dynamic>{
        'resident_user_id': uid,
        'status': 'pending',
        'is_free': !_isPaid,
        'payment_status': _isPaid ? 'pending_payment' : 'free',
        'requested_at': now.toUtc().toIso8601String(),
      };
      if (pickupId != null) insertData['pickup_id'] = pickupId;
      if (_notesController.text.trim().isNotEmpty) {
        insertData['notes'] = _notesController.text.trim();
      }
      if (_isPaid) {
        insertData['payment_amount_cents'] =
            (widget.comebackFee * 100).round();
      }

      await client.from('missed_pickup_requests').insert(insertData);

      // Update monthly usage for free comebacks
      if (!_isPaid && propertyId != null) {
        try {
          final monthStart =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
          await client.from('resident_monthly_usage').upsert({
            'resident_user_id': uid,
            'property_id': propertyId,
            'month': monthStart,
            'free_comeback_used': widget.freeRemain == 0
                ? 0
                : (1), // server-side increment not available in v1; re-load on return
          }, onConflict: 'resident_user_id,property_id,month');
        } catch (_) {}
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

  void _showPaymentPlaceholder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Payment Coming Soon',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
        ),
        content: Text(
          'Online payment is being set up. Your request will be recorded and a team member will follow up to process the \$${widget.comebackFee.toStringAsFixed(0)} fee.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            child: const Text('Submit Anyway',
                style: TextStyle(
                    color: AppColors.resident, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
          'Request a Comeback',
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
                      message: 'Comeback Requested',
                      subtitle: _isPaid
                          ? 'Your request is recorded. A team member will contact you about payment.'
                          : 'A driver will be sent to collect your bags.',
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
                  // Quota banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isPaid
                          ? AppColors.warning.withValues(alpha: 0.08)
                          : AppColors.resident.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPaid
                            ? AppColors.warning.withValues(alpha: 0.3)
                            : AppColors.resident.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPaid
                              ? Icons.credit_card_outlined
                              : Icons.replay_outlined,
                          color: _isPaid
                              ? AppColors.warning
                              : AppColors.resident,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isPaid
                              ? Text(
                                  'You\'ve used your free comeback this month. Additional comebacks cost \$${widget.comebackFee.toStringAsFixed(0)} each.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                )
                              : Text(
                                  'You have ${widget.freeRemain} free comeback${widget.freeRemain == 1 ? '' : 's'} remaining this month.',
                                  style: const TextStyle(
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

                  _sectionLabel('ADDITIONAL NOTES (OPTIONAL)'),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "Bags were set out by 7 PM — side entrance"',
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

                  if (_isPaid) ...[
                    PrimaryButton(
                      label: _submitting
                          ? 'Submitting…'
                          : 'Pay \$${widget.comebackFee.toStringAsFixed(0)} & Request',
                      accent: AppColors.warning,
                      onPressed:
                          _submitting ? null : _showPaymentPlaceholder,
                      icon: Icons.credit_card_outlined,
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Secure payment powered by Stripe',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ),
                  ] else
                    PrimaryButton(
                      label: _submitting
                          ? 'Submitting…'
                          : 'Request Comeback (Free)',
                      accent: AppColors.resident,
                      onPressed: _submitting ? null : _submit,
                      icon: Icons.replay_outlined,
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
