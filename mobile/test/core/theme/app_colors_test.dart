import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('background is near-black, not pure black', () {
      expect(AppColors.background, isNot(const Color(0xFF000000)));
      expect(AppColors.background.red, lessThan(20));
      expect(AppColors.background.green, lessThan(20));
      expect(AppColors.background.blue, lessThan(20));
    });

    test('surface scale is progressively lighter than background', () {
      final bg = AppColors.background.computeLuminance();
      final s1 = AppColors.surface1.computeLuminance();
      final s2 = AppColors.surface2.computeLuminance();
      expect(s1, greaterThan(bg));
      expect(s2, greaterThan(s1));
    });

    test('role accent colors are distinct', () {
      final accents = {AppColors.resident, AppColors.worker, AppColors.manager, AppColors.owner};
      expect(accents.length, 4); // all unique
    });

    test('resident accent is green-family', () {
      expect(AppColors.resident.green, greaterThan(AppColors.resident.red));
      expect(AppColors.resident.green, greaterThan(AppColors.resident.blue));
    });

    test('worker accent is amber-family', () {
      expect(AppColors.worker.red, greaterThan(AppColors.worker.blue));
      expect(AppColors.worker.green, greaterThan(AppColors.worker.blue));
    });

    test('text colors have correct relative luminance ordering', () {
      final primary = AppColors.textPrimary.computeLuminance();
      final secondary = AppColors.textSecondary.computeLuminance();
      final muted = AppColors.textMuted.computeLuminance();
      expect(primary, greaterThan(secondary));
      expect(secondary, greaterThan(muted));
    });
  });
}
