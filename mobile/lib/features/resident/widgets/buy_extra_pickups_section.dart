import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/payments/stripe_checkout.dart';
import '../../../core/theme/app_colors.dart';
import '../models/comeback_pricing.dart';

/// Purchase comeback packs; credits roll over on [resident_units.purchased_comeback_balance].
class BuyExtraPickupsSection extends StatefulWidget {
  const BuyExtraPickupsSection({
    super.key,
    required this.onPurchased,
  });

  final VoidCallback onPurchased;

  @override
  State<BuyExtraPickupsSection> createState() => _BuyExtraPickupsSectionState();
}

class _BuyExtraPickupsSectionState extends State<BuyExtraPickupsSection> {
  bool _busy = false;

  Future<void> _purchase(ComebackPack pack) async {
    setState(() => _busy = true);
    try {
      await StripeCheckout.start(kind: 'pack', quantity: pack.quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete payment in Stripe. Credits are added after checkout succeeds.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onPurchased();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BUY EXTRA PICKUPS',
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Purchased comebacks roll over month to month. Your free monthly comeback does not.',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ...kComebackPacks.map((pack) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _busy ? null : () => _purchase(pack),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pack.label,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Banked for future requests',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${pack.priceDollars}',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.rlvBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.rlvBlue,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
