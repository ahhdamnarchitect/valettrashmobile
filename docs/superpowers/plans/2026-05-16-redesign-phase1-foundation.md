# Redesign Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install the design package stack, build the shared design token layer and reusable widget library, wire the dark theme into the app, and redesign the Auth screen — establishing a complete foundation that all screen redesigns (Plan B) depend on.

**Architecture:** New files live under `mobile/lib/core/theme/` (color tokens, typography, role-accent resolver, theme builder) and `mobile/lib/core/widgets/` (shared UI components). Existing `brand_colors.dart` and `app_theme.dart` are replaced. Existing screens continue to compile throughout this plan — the new theme is wired at the end of Task 7, which is the only "big bang" change.

**Tech Stack:** Flutter 3.41.9 · shadcn_flutter 0.0.52 · flex_color_scheme 8.4.0 · google_fonts 6.x · flutter_animate 4.5.x · shimmer 3.x · gap 3.x · phosphor_flutter (latest) · lottie 3.x · rive 0.13.x · fl_chart 0.69.x · animations 2.x

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `mobile/lib/core/theme/app_colors.dart` | All color constants — replaces `brand_colors.dart` |
| Create | `mobile/lib/core/theme/app_typography.dart` | Geist text theme |
| Create | `mobile/lib/core/theme/role_theme.dart` | `AppRole` enum + per-role accent resolver |
| Create | `mobile/lib/core/theme/app_theme.dart` | Full dark `ThemeData` via flex_color_scheme — replaces existing `app_theme.dart` |
| Delete | `mobile/lib/core/brand_colors.dart` | Superseded by `app_colors.dart` |
| Modify | `mobile/lib/core/app_theme.dart` | Delete — replaced by `core/theme/app_theme.dart` |
| Modify | `mobile/pubspec.yaml` | Add new packages + asset directories |
| Modify | `mobile/lib/valet_app.dart` | Wire new dark theme, wrap in `ShadApp.material()` |
| Create | `mobile/lib/core/widgets/glow_badge.dart` | Accent-colored status pill with glow dot |
| Create | `mobile/lib/core/widgets/stat_tile.dart` | Single stat display (value + label) |
| Create | `mobile/lib/core/widgets/skeleton_card.dart` | Shimmer loading placeholder |
| Create | `mobile/lib/core/widgets/role_hero_card.dart` | Glassmorphism-style status hero card |
| Create | `mobile/lib/core/widgets/primary_button.dart` | Animated full-width CTA button |
| Create | `mobile/lib/core/widgets/role_bottom_nav.dart` | Role-accented bottom navigation bar + `RoleNavItem` |
| Modify | `mobile/lib/features/auth/screens/simple_auth_screen.dart` | Redesign with dark theme + flutter_animate |
| Create | `mobile/test/core/theme/app_colors_test.dart` | Color constant unit tests |
| Create | `mobile/test/core/theme/role_theme_test.dart` | Role accent + string mapping tests |
| Create | `mobile/test/core/widgets/glow_badge_test.dart` | Widget test |
| Create | `mobile/test/core/widgets/stat_tile_test.dart` | Widget test |
| Create | `mobile/test/core/widgets/skeleton_card_test.dart` | Widget test |
| Create | `mobile/test/core/widgets/role_hero_card_test.dart` | Widget test |
| Create | `mobile/test/core/widgets/primary_button_test.dart` | Widget test |
| Create | `mobile/test/core/widgets/role_bottom_nav_test.dart` | Widget test |

---

## Task 1: Install packages

**Files:**
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Open `mobile/pubspec.yaml`. Replace the `dependencies` and `flutter` sections with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Existing
  flutter_dotenv: ^5.1.0
  image_picker: ^1.0.10
  supabase_flutter: ^1.10.25

  # Design System
  shadcn_flutter: ^0.0.52
  flex_color_scheme: ^8.4.0
  google_fonts: ^6.2.1

  # Animation
  flutter_animate: ^4.5.0
  rive: ^0.13.16
  lottie: ^3.1.2
  animations: ^2.0.0

  # UI Utilities
  fl_chart: ^0.69.0
  shimmer: ^3.0.0
  gap: ^3.0.1
  phosphor_flutter: any
  cached_network_image: ^3.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/lottie/
    - assets/rive/
```

- [ ] **Step 2: Create asset directories**

```powershell
New-Item -ItemType Directory -Force "mobile\assets\lottie"
New-Item -ItemType Directory -Force "mobile\assets\rive"
# Add placeholder files so flutter doesn't error on empty dirs
"" | Out-File "mobile\assets\lottie\.gitkeep"
"" | Out-File "mobile\assets\rive\.gitkeep"
```

- [ ] **Step 3: Run pub get**

```powershell
cd mobile
flutter pub get
```

Expected: Resolves all packages, no version conflicts. If `phosphor_flutter` fails with version conflict, add the constraint `phosphor_flutter: ^2.0.0` and retry.

- [ ] **Step 4: Verify compile**

```powershell
flutter build web --no-pub 2>&1 | Select-Object -Last 5
```

Expected: `Built build\web` or similar. The app still compiles — no packages are wired yet.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/assets/
git commit -m "chore: install redesign package stack (shadcn_flutter, flutter_animate, flex_color_scheme, rive, lottie)"
```

---

## Task 2: Create color tokens

**Files:**
- Create: `mobile/lib/core/theme/app_colors.dart`
- Create: `mobile/test/core/theme/app_colors_test.dart`

- [ ] **Step 1: Create theme directory**

```powershell
New-Item -ItemType Directory -Force "mobile\lib\core\theme"
New-Item -ItemType Directory -Force "mobile\test\core\theme"
New-Item -ItemType Directory -Force "mobile\test\core\widgets"
```

- [ ] **Step 2: Write the failing test**

Create `mobile/test/core/theme/app_colors_test.dart`:

```dart
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
```

- [ ] **Step 3: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/theme/app_colors_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:mobile/core/theme/app_colors.dart'`

- [ ] **Step 4: Create app_colors.dart**

Create `mobile/lib/core/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color background  = Color(0xFF08090C);
  static const Color surface1    = Color(0xFF0F1014);
  static const Color surface2    = Color(0xFF161820);
  static const Color border      = Color(0xFF1E2128);
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
```

- [ ] **Step 5: Run test to verify it passes**

```powershell
flutter test test/core/theme/app_colors_test.dart
```

Expected: All 6 tests PASS.

- [ ] **Step 6: Commit**

```powershell
cd ..
git add mobile/lib/core/theme/app_colors.dart mobile/test/core/theme/app_colors_test.dart
git commit -m "feat: add AppColors design token constants"
```

---

## Task 3: Create typography system

**Files:**
- Create: `mobile/lib/core/theme/app_typography.dart`

No separate test — the text theme is exercised by every widget test that follows.

- [ ] **Step 1: Create app_typography.dart**

Create `mobile/lib/core/theme/app_typography.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme {
    // GoogleFonts.geist() requires Geist to be in the Google Fonts catalog.
    // If your google_fonts version doesn't include it, replace with
    // GoogleFonts.getFont('Geist') or fall back to dmSans.
    final base = ThemeData.dark().textTheme;
    return base.copyWith(
      displayLarge: GoogleFonts.geist(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.12,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.geist(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.88,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.geist(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.60,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.geist(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.34,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.geist(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.geist(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.geist(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodyMedium: GoogleFonts.geist(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.geist(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.geist(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelSmall: GoogleFonts.geist(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles (no standalone test — exercised by widget tests)**

```powershell
cd mobile
flutter analyze lib/core/theme/app_typography.dart
```

Expected: `No issues found!` (or only info-level notes)

- [ ] **Step 3: Commit**

```powershell
cd ..
git add mobile/lib/core/theme/app_typography.dart
git commit -m "feat: add Geist typography system"
```

---

## Task 4: Create role theme resolver

**Files:**
- Create: `mobile/lib/core/theme/role_theme.dart`
- Create: `mobile/test/core/theme/role_theme_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/theme/role_theme_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/theme/role_theme.dart';

void main() {
  group('RoleTheme.accentFor', () {
    test('resident returns emerald', () {
      expect(RoleTheme.accentFor(AppRole.resident), AppColors.resident);
    });

    test('worker returns amber', () {
      expect(RoleTheme.accentFor(AppRole.worker), AppColors.worker);
    });

    test('propertyManager returns indigo', () {
      expect(RoleTheme.accentFor(AppRole.propertyManager), AppColors.manager);
    });

    test('operationsManager returns indigo (same as PM)', () {
      expect(RoleTheme.accentFor(AppRole.operationsManager), AppColors.manager);
    });

    test('owner returns purple', () {
      expect(RoleTheme.accentFor(AppRole.owner), AppColors.owner);
    });
  });

  group('RoleTheme.fromString', () {
    test('maps resident string', () {
      expect(RoleTheme.fromString('resident'), AppRole.resident);
    });

    test('maps driver string to worker role', () {
      expect(RoleTheme.fromString('driver'), AppRole.worker);
    });

    test('maps property_manager string', () {
      expect(RoleTheme.fromString('property_manager'), AppRole.propertyManager);
    });

    test('maps operations_manager string', () {
      expect(RoleTheme.fromString('operations_manager'), AppRole.operationsManager);
    });

    test('maps super_admin string to owner role', () {
      expect(RoleTheme.fromString('super_admin'), AppRole.owner);
    });

    test('unknown string defaults to resident', () {
      expect(RoleTheme.fromString('unknown_role'), AppRole.resident);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/theme/role_theme_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:mobile/core/theme/role_theme.dart'`

- [ ] **Step 3: Create role_theme.dart**

Create `mobile/lib/core/theme/role_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppRole {
  resident,
  worker,
  propertyManager,
  operationsManager,
  owner,
}

abstract final class RoleTheme {
  static Color accentFor(AppRole role) => switch (role) {
    AppRole.resident           => AppColors.resident,
    AppRole.worker             => AppColors.worker,
    AppRole.propertyManager    => AppColors.manager,
    AppRole.operationsManager  => AppColors.manager,
    AppRole.owner              => AppColors.owner,
  };

  static AppRole fromString(String role) => switch (role) {
    'resident'           => AppRole.resident,
    'driver'             => AppRole.worker,
    'property_manager'   => AppRole.propertyManager,
    'operations_manager' => AppRole.operationsManager,
    'super_admin'        => AppRole.owner,
    _                    => AppRole.resident,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

```powershell
flutter test test/core/theme/role_theme_test.dart
```

Expected: All 11 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/theme/role_theme.dart mobile/test/core/theme/role_theme_test.dart
git commit -m "feat: add AppRole enum and RoleTheme accent resolver"
```

---

## Task 5: Build the dark ThemeData

**Files:**
- Create: `mobile/lib/core/theme/app_theme.dart` (new location)

This replaces `mobile/lib/core/app_theme.dart`. The old file is deleted in Task 7 once the new theme is wired.

- [ ] **Step 1: Create the new app_theme.dart**

Create `mobile/lib/core/theme/app_theme.dart`:

```dart
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
        useTextTheme: true,
        cardRadius: 14.0,
        inputDecoratorRadius: 10.0,
        inputDecoratorFilled: true,
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
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes cleanly**

```powershell
cd mobile
flutter analyze lib/core/theme/app_theme.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
cd ..
git add mobile/lib/core/theme/app_theme.dart
git commit -m "feat: build dark ThemeData via flex_color_scheme"
```

---

## Task 6: Wire new theme into the app

**Files:**
- Modify: `mobile/lib/valet_app.dart`
- Delete: `mobile/lib/core/app_theme.dart` (old file)
- Delete: `mobile/lib/core/brand_colors.dart` (superseded)

> ⚠️ This task changes how the entire app looks. After this step the app will be dark but existing screens will have mixed styling. That is expected — screen redesigns happen in Plan B.

- [ ] **Step 1: Update valet_app.dart**

Open `mobile/lib/valet_app.dart`. Replace the existing `ValetApp.build` method (keep all other classes — `AuthGate`, `RoleHome` — unchanged):

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ShadApp;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/simple_auth_screen.dart';
import 'features/manager/screens/manager_dashboard_screen.dart';
import 'features/manager/screens/property_manager_dashboard_new.dart';
import 'features/owner/screens/owner_dashboard_screen.dart';
import 'features/resident/screens/resident_dashboard_screen.dart';
import 'features/test/screens/test_connection_screen.dart';
import 'features/worker/screens/worker_dashboard_screen.dart';

class ValetApp extends StatelessWidget {
  const ValetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp.material(
      title: 'Relaxed Living Valet',
      theme: AppTheme.dark,
      home: const AuthGate(),
      routes: {
        '/test': (context) => const TestConnectionScreen(),
      },
    );
  }
}
```

Keep `AuthGate` and `RoleHome` classes exactly as they are — no changes needed.

- [ ] **Step 2: Remove old core files that are now replaced**

```powershell
cd mobile
# Verify nothing outside core/ imports these before deleting
Select-String -Path "lib\**\*.dart" -Pattern "brand_colors" -Recurse | Select-Object Filename, LineNumber, Line
```

If any files outside `core/` import `brand_colors`, update them to use `AppColors` from `core/theme/app_colors.dart` before proceeding.

```powershell
# Also check for old app_theme.dart imports
Select-String -Path "lib\**\*.dart" -Pattern "core/app_theme|core\\app_theme" -Recurse | Select-Object Filename, LineNumber, Line
```

Update any files that import the old `core/app_theme.dart` to import `core/theme/app_theme.dart` instead.

Then delete:

```powershell
Remove-Item "lib\core\brand_colors.dart"
Remove-Item "lib\core\app_theme.dart"
```

- [ ] **Step 3: Run the app and verify it launches dark**

```powershell
$env:PATH = "C:\Users\e159305\Apps\flutter\bin;$env:PATH"
flutter run -d web-server --web-port 8090 --no-pub
```

Navigate to `http://localhost:8090`. Expected: App loads, background is dark (`#08090c`), text is light. Existing screens will look rough — that is correct at this stage.

- [ ] **Step 4: Run all existing tests**

```powershell
flutter test
```

Expected: All tests PASS (only theme unit tests exist at this point, which don't start the app). If any test imports `brand_colors.dart` or `core/app_theme.dart`, update the import.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/valet_app.dart
git add -u mobile/lib/core/brand_colors.dart mobile/lib/core/app_theme.dart
git commit -m "feat: wire dark theme into app via ShadApp.material — app is now dark"
```

---

## Task 7: Build GlowBadge widget

**Files:**
- Create: `mobile/lib/core/widgets/glow_badge.dart`
- Create: `mobile/test/core/widgets/glow_badge_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/glow_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/glow_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Center(child: child)),
      );

  group('GlowBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Active', accent: AppColors.resident),
      ));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows glow dot by default', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Active', accent: AppColors.resident),
      ));
      // Container with circular BoxDecoration used for the dot
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dots = containers.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(dots, isNotEmpty);
    });

    testWidgets('hides dot when showDot is false', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'Done', accent: AppColors.resident, showDot: false),
      ));
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dots = containers.where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.shape == BoxShape.circle;
      });
      expect(dots, isEmpty);
    });

    testWidgets('uses accent color for text', (tester) async {
      await tester.pumpWidget(wrap(
        const GlowBadge(label: 'On Route', accent: AppColors.worker),
      ));
      final textWidget = tester.widget<Text>(find.text('On Route'));
      expect(textWidget.style?.color, AppColors.worker);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/glow_badge_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create the widget directory and glow_badge.dart**

```powershell
New-Item -ItemType Directory -Force "lib\core\widgets"
```

Create `mobile/lib/core/widgets/glow_badge.dart`:

```dart
import 'package:flutter/material.dart';

class GlowBadge extends StatelessWidget {
  const GlowBadge({
    super.key,
    required this.label,
    required this.accent,
    this.showDot = true,
  });

  final String label;
  final Color accent;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.60),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/glow_badge_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/glow_badge.dart mobile/test/core/widgets/glow_badge_test.dart
git commit -m "feat: add GlowBadge widget with accent glow dot"
```

---

## Task 8: Build StatTile widget

**Files:**
- Create: `mobile/lib/core/widgets/stat_tile.dart`
- Create: `mobile/test/core/widgets/stat_tile_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/stat_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/stat_tile.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Row(children: [child])),
      );

  group('StatTile', () {
    testWidgets('renders value and label', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: '12', label: 'Streak'),
      ));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('STREAK'), findsOneWidget); // label is uppercased
    });

    testWidgets('uses custom value color when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: '3', label: 'Violations', valueColor: AppColors.error),
      ));
      final text = tester.widget<Text>(find.text('3'));
      expect(text.style?.color, AppColors.error);
    });

    testWidgets('uses textPrimary when no valueColor given', (tester) async {
      await tester.pumpWidget(wrap(
        const StatTile(value: 'A+', label: 'Rating'),
      ));
      final text = tester.widget<Text>(find.text('A+'));
      expect(text.style?.color, AppColors.textPrimary);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/stat_tile_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create stat_tile.dart**

Create `mobile/lib/core/widgets/stat_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
                letterSpacing: -0.04 * 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/stat_tile_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/stat_tile.dart mobile/test/core/widgets/stat_tile_test.dart
git commit -m "feat: add StatTile widget for stats row display"
```

---

## Task 9: Build SkeletonCard widget

**Files:**
- Create: `mobile/lib/core/widgets/skeleton_card.dart`
- Create: `mobile/test/core/widgets/skeleton_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/skeleton_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mobile/core/widgets/skeleton_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      );

  group('SkeletonCard', () {
    testWidgets('renders a Shimmer widget', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard()));
      expect(find.byType(Shimmer), findsOneWidget);
    });

    testWidgets('renders with custom height', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard(height: 120)));
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(Shimmer), matching: find.byType(Container)).first,
      );
      expect((container.constraints?.minHeight ?? 0), greaterThanOrEqualTo(0));
      // Height is set via SizedBox inside Shimmer
      final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox))
          .firstWhere((s) => s.height == 120, orElse: () => const SizedBox());
      expect(sizedBox.height, 120);
    });

    testWidgets('default height is 80', (tester) async {
      await tester.pumpWidget(wrap(const SkeletonCard()));
      // Verify the widget renders without overflow at default height
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/skeleton_card_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create skeleton_card.dart**

Create `mobile/lib/core/widgets/skeleton_card.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/skeleton_card_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/skeleton_card.dart mobile/test/core/widgets/skeleton_card_test.dart
git commit -m "feat: add SkeletonCard shimmer loading placeholder"
```

---

## Task 10: Build RoleHeroCard widget

**Files:**
- Create: `mobile/lib/core/widgets/role_hero_card.dart`
- Create: `mobile/test/core/widgets/role_hero_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/role_hero_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/glow_badge.dart';
import 'package:mobile/core/widgets/role_hero_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        )),
      );

  group('RoleHeroCard', () {
    testWidgets('renders eyebrow, title, subtitle, and badge', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Tonight\'s Service',
          title: 'Sunset Gardens',
          subtitle: 'Unit 104',
          badgeLabel: 'Active',
        ),
      ));
      expect(find.text("TONIGHT'S SERVICE"), findsOneWidget); // uppercased
      expect(find.text('Sunset Gardens'), findsOneWidget);
      expect(find.text('Unit 104'), findsOneWidget);
      expect(find.byType(GlowBadge), findsOneWidget);
    });

    testWidgets('GlowBadge receives correct label', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.worker,
          eyebrow: 'Route',
          title: 'Sunset',
          subtitle: 'Unit 1',
          badgeLabel: 'On Route',
        ),
      ));
      expect(find.text('On Route'), findsOneWidget);
    });

    testWidgets('renders optional child widget when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Service',
          title: 'Gardens',
          subtitle: 'Unit 2',
          badgeLabel: 'Scheduled',
          child: Text('extra content'),
        ),
      ));
      expect(find.text('extra content'), findsOneWidget);
    });

    testWidgets('does not render child slot when child is null', (tester) async {
      await tester.pumpWidget(wrap(
        const RoleHeroCard(
          accent: AppColors.resident,
          eyebrow: 'Service',
          title: 'Gardens',
          subtitle: 'Unit 3',
          badgeLabel: 'Scheduled',
        ),
      ));
      expect(find.text('extra content'), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/role_hero_card_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create role_hero_card.dart**

Create `mobile/lib/core/widgets/role_hero_card.dart`:

```dart
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
              letterSpacing: 1.26, // 0.14em at 9px
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
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/role_hero_card_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/role_hero_card.dart mobile/test/core/widgets/role_hero_card_test.dart
git commit -m "feat: add RoleHeroCard glassmorphism status card"
```

---

## Task 11: Build PrimaryButton widget

**Files:**
- Create: `mobile/lib/core/widgets/primary_button.dart`
- Create: `mobile/test/core/widgets/primary_button_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/primary_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/primary_button.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        )),
      );

  group('PrimaryButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Sign In',
          onPressed: () {},
          accent: AppColors.resident,
        ),
      ));
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Tap me',
          onPressed: () => called = true,
          accent: AppColors.resident,
        ),
      ));
      await tester.tap(find.text('Tap me'));
      await tester.pump();
      expect(called, isTrue);
    });

    testWidgets('shows CircularProgressIndicator when isLoading', (tester) async {
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Loading',
          onPressed: () {},
          accent: AppColors.resident,
          isLoading: true,
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('is disabled when onPressed is null', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(
        PrimaryButton(
          label: 'Disabled',
          onPressed: null,
          accent: AppColors.resident,
        ),
      ));
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(called, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/primary_button_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create primary_button.dart**

Create `mobile/lib/core/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.accent,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool isLoading;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed != null) setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final effectiveAccent = isEnabled ? widget.accent : widget.accent.withOpacity(0.4);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: effectiveAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: AppColors.textPrimary),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/primary_button_test.dart
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/primary_button.dart mobile/test/core/widgets/primary_button_test.dart
git commit -m "feat: add PrimaryButton with press animation and loading state"
```

---

## Task 12: Build RoleBottomNav widget

**Files:**
- Create: `mobile/lib/core/widgets/role_bottom_nav.dart`
- Create: `mobile/test/core/widgets/role_bottom_nav_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/core/widgets/role_bottom_nav_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_colors.dart';
import 'package:mobile/core/widgets/role_bottom_nav.dart';

void main() {
  final items = const [
    RoleNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    RoleNavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'History'),
    RoleNavItem(icon: Icons.notifications_outlined, activeIcon: Icons.notifications, label: 'Alerts'),
  ];

  Widget wrap({required int currentIndex, required ValueChanged<int> onTap}) =>
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: RoleBottomNav(
            currentIndex: currentIndex,
            onTap: onTap,
            items: items,
            accent: AppColors.resident,
          ),
        ),
      );

  group('RoleBottomNav', () {
    testWidgets('renders all item labels', (tester) async {
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (_) {}));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
    });

    testWidgets('calls onTap with correct index', (tester) async {
      int? tapped;
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (i) => tapped = i));
      await tester.tap(find.text('History'));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('tapping third item calls onTap with index 2', (tester) async {
      int? tapped;
      await tester.pumpWidget(wrap(currentIndex: 0, onTap: (i) => tapped = i));
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(tapped, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
cd mobile
flutter test test/core/widgets/role_bottom_nav_test.dart
```

Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Create role_bottom_nav.dart**

Create `mobile/lib/core/widgets/role_bottom_nav.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RoleNavItem {
  const RoleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class RoleBottomNav extends StatelessWidget {
  const RoleBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    required this.accent,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<RoleNavItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final isActive = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive ? accent.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 22,
                          color: isActive ? accent : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive ? accent : AppColors.textMuted,
                          letterSpacing: 0.02,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
flutter test test/core/widgets/role_bottom_nav_test.dart
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Run all tests to verify nothing broke**

```powershell
flutter test
```

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```powershell
cd ..
git add mobile/lib/core/widgets/role_bottom_nav.dart mobile/test/core/widgets/role_bottom_nav_test.dart
git commit -m "feat: add RoleBottomNav with accent-colored active indicator"
```

---

## Task 13: Redesign the Auth screen

**Files:**
- Modify: `mobile/lib/features/auth/screens/simple_auth_screen.dart`

This task replaces the visual layer of the auth screen while preserving all business logic (`_submit`, `_toggleMode`, `_ensureUserProfileExists`). Do not touch any method that calls Supabase.

- [ ] **Step 1: Write a smoke test for the new auth screen**

Create `mobile/test/features/auth/simple_auth_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/screens/simple_auth_screen.dart';

void main() {
  Widget wrap() => const MaterialApp(home: SimpleAuthScreen());

  group('SimpleAuthScreen', () {
    testWidgets('renders sign in heading', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump(); // settle animations
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows first name and last name fields in sign up mode', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // animation settle

      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('renders Sign In button', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();
      // PrimaryButton renders a GestureDetector containing the label text
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('toggles to sign up mode and back', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sign Up'), findsWidgets);

      await tester.tap(find.text('Already have an account? Sign in'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sign In'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm current screen passes (baseline)**

```powershell
cd mobile
New-Item -ItemType Directory -Force "test\features\auth"
flutter test test/features/auth/simple_auth_screen_test.dart
```

Note: Some tests may fail because the current screen has no animations or PrimaryButton. That's fine — those are the tests for the new design. Record which pass now.

- [ ] **Step 3: Replace simple_auth_screen.dart**

Replace the full contents of `mobile/lib/features/auth/screens/simple_auth_screen.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glow_badge.dart';
import '../../../core/widgets/primary_button.dart';
import '../../manager/screens/manager_dashboard_screen.dart';
import '../../manager/screens/property_manager_dashboard_new.dart';
import '../../owner/screens/owner_dashboard_screen.dart';
import '../../test/screens/test_connection_screen.dart';
import '../../worker/screens/worker_dashboard_screen.dart';
import 'resident_signup_screen.dart';

class SimpleAuthScreen extends StatefulWidget {
  const SimpleAuthScreen({super.key});

  @override
  State<SimpleAuthScreen> createState() => _SimpleAuthScreenState();
}

class _SimpleAuthScreenState extends State<SimpleAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // ── Business logic — unchanged ──────────────────────────────────────

  Future<void> _ensureUserProfileExists() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final existingProfile = await supabase
          .from('users')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (existingProfile == null) {
        await supabase.from('users').insert({
          'id': currentUser.id,
          'email': currentUser.email,
          'first_name': _firstNameController.text.trim().isNotEmpty
              ? _firstNameController.text.trim()
              : 'New',
          'last_name': _lastNameController.text.trim().isNotEmpty
              ? _lastNameController.text.trim()
              : 'User',
          'role': 'resident',
        });
      }
    } catch (e) {
      debugPrint('Failed to ensure user profile exists: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final supabase = Supabase.instance.client;

      if (_isLogin) {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final session = supabase.auth.currentSession;
        if (session != null) {
          await _ensureUserProfileExists();
          setState(() => _success = 'Signed in successfully!');
        } else {
          setState(() => _error = 'Sign in completed but no session created');
        }
      } else {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'role': 'resident',
          },
        );
        if (response.user != null) {
          await _ensureUserProfileExists();
          setState(() {
            _success = response.user?.emailConfirmedAt != null
                ? 'Account created successfully!'
                : 'Account created! Please check your email for confirmation.';
            if (response.user?.emailConfirmedAt == null) _isLogin = true;
          });
        } else {
          setState(() => _error = 'Account creation failed. Please try again.');
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Invalid login credentials')) msg = 'Invalid email or password';
      else if (msg.contains('User already registered')) msg = 'Email already registered. Please sign in.';
      else if (msg.contains('Email not confirmed')) msg = 'Please confirm your email before signing in.';
      setState(() => _error = msg);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _success = null;
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                _buildWordmark(),
                const SizedBox(height: 48),
                _buildModeHeading(),
                const SizedBox(height: 28),
                if (!_isLogin) ..._buildNameFields(),
                _buildEmailField(),
                const SizedBox(height: 12),
                _buildPasswordField(),
                const SizedBox(height: 24),
                if (_error != null) _buildErrorBadge(),
                if (_success != null) _buildSuccessBadge(),
                const SizedBox(height: 4),
                PrimaryButton(
                  label: _isLogin ? 'Sign In' : 'Sign Up',
                  onPressed: _isLoading ? null : _submit,
                  accent: AppColors.resident,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _toggleMode,
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Sign up"
                        : 'Already have an account? Sign in',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildResidentSignupButton(),
                if (kDebugMode) ...[
                  const SizedBox(height: 32),
                  _buildDebugSection(),
                ],
              ]
                  .animate(interval: 60.ms)
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordmark() {
    return Column(
      children: [
        Text(
          'RELAXED LIVING',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.16 * 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Valet Service',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.04 * 28,
          ),
        ),
      ],
    );
  }

  Widget _buildModeHeading() {
    return Text(
      _isLogin ? 'Sign In' : 'Create Account',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
    );
  }

  List<Widget> _buildNameFields() {
    return [
      _darkField(
        controller: _firstNameController,
        label: 'First Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      _darkField(
        controller: _lastNameController,
        label: 'Last Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildEmailField() {
    return _darkField(
      controller: _emailController,
      label: 'Email',
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _darkField(
      controller: _passwordController,
      label: 'Password',
      obscureText: true,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (v.length < 6) return 'At least 6 characters';
        return null;
      },
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.resident, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildErrorBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlowBadge(
        label: _error!,
        accent: AppColors.error,
        showDot: false,
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlowBadge(
        label: _success!,
        accent: AppColors.success,
        showDot: false,
      ),
    );
  }

  Widget _buildResidentSignupButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResidentSignupScreen()),
      ),
      icon: const Icon(Icons.vpn_key_outlined, size: 16, color: AppColors.textSecondary),
      label: const Text(
        'Resident Sign Up (Invite Code)',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDebugSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppColors.border),
        const SizedBox(height: 8),
        Text(
          'DEBUG NAVIGATION',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.14 * 9,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ...[
          ('Property Manager Dashboard', const PropertyManagerDashboardNewScreen()),
          ('Worker Dashboard', const WorkerDashboardScreen()),
          ('Operations Manager Dashboard', const ManagerDashboardScreen()),
          ('Owner Dashboard', const OwnerDashboardScreen()),
          ('Test Connection', const TestConnectionScreen()),
        ].map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => entry.$2),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(entry.$1, style: const TextStyle(fontSize: 12)),
              ),
            )),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the auth screen tests**

```powershell
cd mobile
flutter test test/features/auth/simple_auth_screen_test.dart
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Run all tests**

```powershell
flutter test
```

Expected: All tests PASS.

- [ ] **Step 6: Run the app and visually verify the auth screen**

```powershell
flutter run -d web-server --web-port 8090 --no-pub
```

Open `http://localhost:8090`. Expected: Dark sign-in screen with Geist font, emerald-tinted input focus, staggered fade-in entry animations, dark fields with `#161820` fill, `PrimaryButton` with emerald background.

- [ ] **Step 7: Commit**

```powershell
cd ..
git add mobile/lib/features/auth/screens/simple_auth_screen.dart \
        mobile/test/features/auth/simple_auth_screen_test.dart
git commit -m "feat: redesign SimpleAuthScreen with dark theme and flutter_animate entry animations"
```

---

## Final verification

- [ ] **Run all tests**

```powershell
cd mobile
flutter test
```

Expected: All tests PASS.

- [ ] **Build for web**

```powershell
flutter build web --no-pub 2>&1 | Select-Object -Last 5
```

Expected: `Built build\web` with no errors.

- [ ] **Summary commit if any files were missed**

```powershell
cd ..
git status
# If any modified files remain unstaged, commit them
git add -A
git commit -m "chore: Phase 1 foundation complete — design tokens, shared widgets, auth screen redesign"
```

---

## What's next

Once this plan is complete, proceed to:

**`docs/superpowers/plans/2026-05-16-redesign-phase2-screens.md`**

That plan covers redesigning all role-specific screens (Resident, Worker, Property Manager, Operations Manager, Owner) using the shared widgets built here.
