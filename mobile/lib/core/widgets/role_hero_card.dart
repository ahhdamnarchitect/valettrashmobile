import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'glow_badge.dart';

class RoleHeroCard extends StatelessWidget {
  const RoleHeroCard({
    super.key,
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    this.showDot = true,
    this.child,
  });

  final Color accent;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final bool showDot;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.26,
              color: accent.withOpacity(0.80),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.66,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          GlowBadge(label: badgeLabel, accent: accent, showDot: showDot),
          if (child != null) ...[
            const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}
