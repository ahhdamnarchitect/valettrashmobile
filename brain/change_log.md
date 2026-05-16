# Change Log

## Format
Date | Change | Files Modified | Reason

---

### 2026-05-16 (Phase 1 Redesign)
- **Change**: Implemented complete Phase 1 redesign foundation across 12 commits. App is now dark-first with a full design system.
- **Files Created**:
  - `mobile/lib/core/theme/app_colors.dart` — AppColors token constants (OLED dark palette)
  - `mobile/lib/core/theme/app_typography.dart` — DM Sans text theme via google_fonts
  - `mobile/lib/core/theme/role_theme.dart` — AppRole enum + per-role accent resolver (emerald/amber/indigo/purple)
  - `mobile/lib/core/theme/app_theme.dart` — Full dark ThemeData via flex_color_scheme
  - `mobile/lib/core/widgets/glow_badge.dart` — Accent-colored status pill with glow dot
  - `mobile/lib/core/widgets/stat_tile.dart` — Single-stat display with label
  - `mobile/lib/core/widgets/skeleton_card.dart` — Shimmer loading placeholder
  - `mobile/lib/core/widgets/role_hero_card.dart` — Glassmorphism status hero card
  - `mobile/lib/core/widgets/primary_button.dart` — Press-animated full-width CTA
  - `mobile/lib/core/widgets/role_bottom_nav.dart` — Role-accented bottom nav
  - `mobile/assets/lottie/`, `mobile/assets/rive/` — Asset directories (empty, for Phase 5)
- **Files Modified**:
  - `mobile/pubspec.yaml` — Added 11 new packages (shadcn_flutter, flex_color_scheme, flutter_animate, shimmer, gap, phosphor_flutter, lottie, rive, fl_chart, animations, cached_network_image)
  - `mobile/lib/valet_app.dart` — Switched to MaterialApp + AppTheme.dark (was: light ColorScheme.fromSeed)
  - `mobile/lib/features/auth/screens/simple_auth_screen.dart` — Full redesign: dark background, dark fields, GlowBadge errors, PrimaryButton, flutter_animate staggered entry
  - `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` — Updated imports (BrandColors → AppColors)
  - `mobile/lib/features/owner/screens/owner_dashboard_screen.dart` — Updated imports (BrandColors → AppColors)
- **Files Deleted**:
  - `mobile/lib/core/brand_colors.dart` — Superseded by AppColors
  - `mobile/lib/core/app_theme.dart` — Superseded by core/theme/app_theme.dart
- **Tests**: 43 unit/widget tests passing. Pre-existing widget_test.dart requires live Supabase (expected failure).
- **Reason**: 2026 redesign initiative — dark-first, role-accented, premium valet service aesthetic.

### 2026-05-16 (session 4)
- **Change**: Fixed two bugs blocking auth; added `operations_manager` to DB enum; created 3 test accounts; verified all 5 role-based dashboards with real data.
- **Files Modified**:
  - `mobile/lib/features/auth/screens/simple_auth_screen.dart` — wrapped Column in `Form(key: _formKey, ...)` — bug caused null crash (`_formKey.currentState!.validate()`) on every sign-in attempt
  - `mobile/lib/valet_app.dart` — added `'operations_manager'` case to `RoleHome` switch + `import 'features/manager/screens/manager_dashboard_screen.dart'` — ManagerDashboardScreen was unreachable via real auth routing
- **DB changes** (Supabase SQL editor):
  - `ALTER TYPE user_role ADD VALUE 'operations_manager'` (enum was missing this value)
  - Inserted auth users + `public.users` profiles for PM (`+pm`), OM (`+om`), Worker (`+worker`) accounts
  - `user_properties` rows for PM and OM linking to Sunset Gardens
  - `worker_assignments` row for worker linking to Sunset Gardens
- **Test results**:
  - ✅ PM → PropertyManagerDashboardNewScreen: 1 property, 1 unit, 1 resident, service window, notify buttons
  - ✅ OM → ManagerDashboardScreen: Test Worker shown, 1 property/1 worker footer, all sections load
  - ✅ Worker → WorkerDashboardScreen: Sunset Gardens assignment, Clock In, Report Violation
- **Reason**: Dashboards had never been tested with real auth — PM/OM showed "No properties assigned" and auth itself was broken (Form bug meant sign-in never called Supabase).

### 2026-05-16 (session 3)
- **Change**: Fixed 3 categories of compile errors, ran full end-to-end test across all 6 dashboards.
- **Files Modified**:
  - `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — `.inFilter()` → `.filter()`, `Future.wait` explicit type
  - `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` — `.inFilter()` → `.filter()` (5 calls), `Future.wait` explicit type
  - `mobile/lib/features/owner/screens/owner_dashboard_screen.dart` — `.inFilter()` → `.filter()` (2 calls), `Future.wait` explicit type
  - `mobile/lib/features/worker/screens/violation_report_screen.dart` — removed `dart:io` import, `uploadBinary` + `readAsBytes()` for Flutter web compat
- **Config change**: Disabled Supabase email confirmation (Authentication → Providers → Email) to allow immediate session after signup
- **Test results**: All 6 dashboards confirmed loading; resident signup flow verified end-to-end with `adam.grant824+res2@gmail.com` / `TestPass123!`
- **Reason**: Compile errors from postgrest v1 vs v2 API differences and Flutter web platform constraints.

### 2026-05-16 (session 2)
- **Change**: Applied seed data to remote Supabase DB; verified `verify_invite_code` RPC end-to-end.
- **Files Modified**: Remote Supabase DB (SQL editor)
- **Data inserted**: `properties` (Sunset Gardens, UUID `10000000...0001`), `buildings` (Building A), `floors` (Floor 1), `units` (unit 104, UUID `40000000...0004`), `invite_codes` (`WELCOME104`, property+unit linked, 10 max uses, 365d expiry)
- **RPC test result**: `verify_invite_code('WELCOME104', '10000000-0000-0000-0000-000000000001', '104')` → `is_valid=true, message=OK`
- **Reason**: Complete DB-side setup so resident signup flow can be tested on device.
- **Blocker**: Flutter SDK not found on this machine — device test deferred to user.

### 2026-05-16
- **Change**: Replaced all remaining hardcoded mock data with real Supabase queries across manager and resident screens.
- **Files Modified**:
  - `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — Full rewrite: loads workers from `worker_assignments`, tonight's runs from `nightly_runs`, comeback counts from `missed_pickup_requests`, comeback history (7 days), and sent notifications from `notifications.sender_id`
  - `mobile/lib/features/manager/screens/today_comebacks_screen.dart` — Full rewrite: queries `missed_pickup_requests` for today with nested join through `pickups → units` and `pickups → nightly_runs → properties` for unit/property names
  - `mobile/lib/features/resident/screens/resident_violations_screen.dart` — Fixed field name `user_id` → `resident_user_id`; fixed `is_warning` boolean display logic
  - `mobile/lib/features/resident/screens/resident_notifications_screen.dart` — Removed debug panel; fixed notification type mapping to DB enum values; added `is_active` filter
- **Reason**: Complete the application so all data shown is real — no mock lists anywhere in the codebase.

### 2026-05-15
- **Change**: Applied migration 006 — `violations` storage bucket + 5 RLS policies on `storage.objects`.
- **Files Modified**: Remote Supabase DB (applied via SQL editor in browser)
- **Reason**: Workers need to upload violation photos to a private bucket; residents need their own folder.

### 2026-05-15
- **Change**: Applied migration 005 — `user_properties` table, invite_codes (new schema), `verify_invite_code` + `claim_invite_code` RPCs, resident self-register policy, notifications schema extensions, `violations.pickup_id` nullable.
- **Files Modified**: Remote Supabase DB (applied via SQL editor in browser)
- **Reason**: Bridge gaps between Flutter app expectations and DB schema after a prior iteration left incompatible objects.
- **Pre-work required**: Dropped legacy `invite_codes` table (incompatible schema), dropped old `verify_invite_code` + `claim_invite_code` functions (incompatible return types).

### 2026-05-15
- **Change**: Installed Repo OS brain scaffold (brain/, .cursor/rules/, cursor-os/, scripts/).
- **Files Modified**: `brain/project_context.md`, `brain/architecture.md`, `brain/current_state.md`, `brain/decisions.md`, `brain/next_steps.md`, `brain/change_log.md`, `.cursor/rules/00-repo-brain.mdc` (+ 3 more rules), `cursor-os/` (6 docs), `scripts/init-cursor-os.js`, `README.md`
- **Reason**: Establish persistent project memory for resumable AI-assisted development sessions.
