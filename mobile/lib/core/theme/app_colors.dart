import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF08090C);
  static const Color surface1     = Color(0xFF0F1014);
  static const Color surface2     = Color(0xFF161820);
  static const Color border       = Color(0xFF1E2128);
  static const Color borderSubtle = Color(0xFF13141A);

  // ── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFF0F0F8);
  static const Color textSecondary = Color(0xFF8B8B9E);
  static const Color textMuted     = Color(0xFF4A4A5A);

  // ── Role accents ─────────────────────────────────────────────────────
  static const Color resident = Color(0xFF10B981); // emerald
  static const Color worker   = Color(0xFFF59E0B); // amber
  static const Color manager  = Color(0xFF6366F1); // indigo
  static const Color owner    = Color(0xFFA855F7); // purple

  // ── Semantic ─────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF10B981);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color error    = Color(0xFFEF4444);
  static const Color info     = Color(0xFF38BDF8);
}

// ── Per-role theme extension ──────────────────────────────────────────────────
// Screens wrap themselves via Theme(data: AppTheme.light) for office roles.
// Use context.roleColors to get the correct palette in build methods.

@immutable
class AppColorsScheme extends ThemeExtension<AppColorsScheme> {
  const AppColorsScheme({
    required this.background,
    required this.surface1,
    required this.surface2,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color background;
  final Color surface1;
  final Color surface2;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  static const dark = AppColorsScheme(
    background:    Color(0xFF08090C),
    surface1:      Color(0xFF0F1014),
    surface2:      Color(0xFF161820),
    border:        Color(0xFF1E2128),
    borderSubtle:  Color(0xFF13141A),
    textPrimary:   Color(0xFFF0F0F8),
    textSecondary: Color(0xFF8B8B9E),
    textMuted:     Color(0xFF4A4A5A),
  );

  static const light = AppColorsScheme(
    background:    Color(0xFFF5F6FA),
    surface1:      Color(0xFFFFFFFF),
    surface2:      Color(0xFFF0F2F5),
    border:        Color(0xFFE3E7EF),
    borderSubtle:  Color(0xFFEEF0F5),
    textPrimary:   Color(0xFF0F1117),
    textSecondary: Color(0xFF4B5563),
    textMuted:     Color(0xFF9CA3AF),
  );

  @override
  AppColorsScheme copyWith({
    Color? background,
    Color? surface1,
    Color? surface2,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) =>
      AppColorsScheme(
        background:    background    ?? this.background,
        surface1:      surface1      ?? this.surface1,
        surface2:      surface2      ?? this.surface2,
        border:        border        ?? this.border,
        borderSubtle:  borderSubtle  ?? this.borderSubtle,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
      );

  @override
  AppColorsScheme lerp(AppColorsScheme? other, double t) {
    if (other == null) return this;
    return AppColorsScheme(
      background:    Color.lerp(background,    other.background,    t)!,
      surface1:      Color.lerp(surface1,      other.surface1,      t)!,
      surface2:      Color.lerp(surface2,      other.surface2,      t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      borderSubtle:  Color.lerp(borderSubtle,  other.borderSubtle,  t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColorsScheme get roleColors =>
      Theme.of(this).extension<AppColorsScheme>() ?? AppColorsScheme.dark;
}
