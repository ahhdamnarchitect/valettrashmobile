import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final flexScheme = FlexColorScheme.dark(
      primary: AppColors.resident,
      primaryContainer: AppColors.surface2,
      secondary: AppColors.worker,
      secondaryContainer: AppColors.surface2,
      tertiary: AppColors.manager,
      tertiaryContainer: AppColors.surface2,
      surface: AppColors.surface1,
      scaffoldBackground: AppColors.background,
      error: AppColors.error,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 12,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        blendOnColors: true,
        useMaterial3Typography: true,
        cardRadius: 14.0,
        inputDecoratorRadius: 10.0,
        inputDecoratorIsFilled: true,
        inputDecoratorFillColor: AppColors.surface2,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorBorderWidth: 1.0,
        inputDecoratorFocusedBorderWidth: 2.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 8.0,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarBackgroundSchemeColor: SchemeColor.surface,
        bottomNavigationBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    );

    return flexScheme.toTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface1,
      dividerColor: AppColors.border,
      textTheme: AppTypography.textTheme,
      primaryTextTheme: AppTypography.textTheme,
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: 22,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      extensions: const [AppColorsScheme.dark],
    );
  }

  static ThemeData get light {
    const c = AppColorsScheme.light;

    final flexScheme = FlexColorScheme.light(
      primary: AppColors.manager,
      primaryContainer: const Color(0xFFEEEFF9),
      secondary: AppColors.owner,
      secondaryContainer: const Color(0xFFF5EEF9),
      tertiary: AppColors.resident,
      surface: c.surface1,
      scaffoldBackground: c.background,
      error: AppColors.error,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 4,
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        blendOnColors: false,
        useMaterial3Typography: true,
        cardRadius: 14.0,
        inputDecoratorRadius: 10.0,
        inputDecoratorIsFilled: true,
        inputDecoratorFillColor: Color(0xFFF0F2F5),
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorBorderWidth: 1.0,
        inputDecoratorFocusedBorderWidth: 2.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        textButtonRadius: 8.0,
        bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
        bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
        bottomNavigationBarBackgroundSchemeColor: SchemeColor.surface,
        bottomNavigationBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
    );

    return flexScheme.toTheme.copyWith(
      scaffoldBackgroundColor: c.background,
      cardColor: c.surface1,
      dividerColor: c.border,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      primaryTextTheme: AppTypography.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      iconTheme: IconThemeData(
        color: c.textSecondary,
        size: 22,
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface1,
        foregroundColor: c.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: c.border,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      extensions: const [AppColorsScheme.light],
    );
  }
}
