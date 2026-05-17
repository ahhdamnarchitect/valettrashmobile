import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 80,
    this.borderRadius = 14,
  });

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface2,
      highlightColor: AppColors.border,
      child: SizedBox(
        height: height,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
