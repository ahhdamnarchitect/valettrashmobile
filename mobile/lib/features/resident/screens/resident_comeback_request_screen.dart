import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/payments/stripe_checkout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/lottie_feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/comeback_pricing.dart';

enum _ComebackCharge { freeMonthly, freePurchased, paidSingle }

class ResidentComebackRequestScreen extends StatefulWidget {
  final int freeRemain;
  final int purchasedBalance;
  final String? propertyId;
  final String? residentUnitId;

  const ResidentComebackRequestScreen({
    super.key,
    required this.freeRemain,
    required this.purchasedBalance,
    this.propertyId,
    this.residentUnitId,
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

  late final _ComebackCharge _charge;

  @override
  void initState() {
    super.initState();
    if (widget.freeRemain > 0) {
      _charge = _ComebackCharge.freeMonthly;
    } else if (widget.purchasedBalance > 0) {
      _charge = _ComebackCharge.freePurchased;
    } else {
      _charge = _ComebackCharge.paidSingle;
    }
  }

  bool get _isPaid => _charge == _ComebackCharge.paidSingle;

  int get _singlePrice =>
      kComebackPacks.firstWhere((p) => p.quantity == 1).priceDollars;

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

      String? pickupId;
      String? propertyId = widget.propertyId;
      String? unitRowId = widget.residentUnitId;
      int purchasedBalance = widget.purchasedBalance;

      try {
        final unitRow = await client
            .from('resident_units')
            .select('id, unit_id, property_id, purchased_comeback_balance')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle();

        if (unitRow != null) {
          unitRowId = unitRow['id']?.toString();
          propertyId ??= unitRow['property_id']?.toString();
          purchasedBalance =
              unitRow['purchased_comeback_balance'] as int? ?? purchasedBalance;
          final unitId = unitRow['unit_id']?.toString();
          if (unitId != null) {
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day)
                .toUtc()
                .toIso8601String();
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
        'is_free': true,
        'payment_status': 'free',
        'requested_at': now.toUtc().toIso8601String(),
      };
      if (pickupId != null) insertData['pickup_id'] = pickupId;
      if (_notesController.text.trim().isNotEmpty) {
        insertData['notes'] = _notesController.text.trim();
      }
      await client.from('missed_pickup_requests').insert(insertData);

      if (propertyId != null) {
        final monthStart =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

        if (_charge == _ComebackCharge.freeMonthly) {
          final usage = await client
              .from('resident_monthly_usage')
              .select('free_comeback_used')
              .eq('resident_user_id', uid)
              .eq('property_id', propertyId)
              .eq('month', monthStart)
              .maybeSingle();
          final used = usage?['free_comeback_used'] as int? ?? 0;
          await client.from('resident_monthly_usage').upsert({
            'resident_user_id': uid,
            'property_id': propertyId,
            'month': monthStart,
            'free_comeback_used': used + 1,
          }, onConflict: 'resident_user_id,property_id,month');
        } else if (_charge == _ComebackCharge.freePurchased &&
            unitRowId != null &&
            purchasedBalance > 0) {
          await client.from('resident_units').update({
            'purchased_comeback_balance': purchasedBalance - 1,
          }).eq('id', unitRowId);
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

  Future<void> _payAndRequest() async {
    setState(() => _submitting = true);
    try {
      await StripeCheckout.start(
        kind: 'comeback',
        notes: _notesController.text,
      );
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
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

  String get _quotaMessage {
    switch (_charge) {
      case _ComebackCharge.freeMonthly:
        return 'Using your free monthly comeback (${widget.freeRemain} left this month). Free comebacks do not roll over.';
      case _ComebackCharge.freePurchased:
        return 'Using 1 banked comeback (${widget.purchasedBalance} remaining). Purchased comebacks roll over month to month.';
      case _ComebackCharge.paidSingle:
        return 'No free or banked comebacks left. This request is \$$_singlePrice (or buy packs: 3 for \$14, 5 for \$20 on Extra Services).';
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
          'Request a Comeback',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context, true),
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
                          ? 'Finish checkout in Stripe if it is still open. The request is queued once payment succeeds.'
                          : 'A driver will be sent to collect your bags.',
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, true),
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
                          child: Text(
                            _quotaMessage,
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
                          : 'Pay \$$_singlePrice & Request',
                      accent: AppColors.warning,
                      onPressed: _submitting ? null : _payAndRequest,
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
