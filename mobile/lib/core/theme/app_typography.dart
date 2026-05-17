import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme {
    final base = ThemeData.dark().textTheme;
    return base.copyWith(
      displayLarge: GoogleFonts.dmSans(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.12,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.88,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.60,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.34,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    );
  }
}
