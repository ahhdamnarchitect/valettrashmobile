# Current State

## Current Objective
Phase 1 redesign foundation complete. App now has a dark design system, shared widget library, and redesigned auth screen. Next priority: Phase 2 — redesign all role-specific dashboards using the new shared widgets.

## Next Action
```powershell
# Run the app (Flutter already on PATH):
cd C:\Users\e159305\Projects\valettrashmobile\mobile
# Use web-server device to control via Playwright, or chrome to open in system browser:
flutter run -d web-server --web-port 8090 --no-pub
# OR: flutter run -d chrome --no-pub
```

## What Exists

- **Supabase DB** (project: `relaxedl-living`, ref: `airpwzzkyjqzeeqizvft`, AWS us-east-2)
  - Status: Fully migrated — migrations 001, 004, 005, 006 applied
  - All tables exist with correct schema, RLS enabled, SECURITY DEFINER RPCs in place
  - `violations` storage bucket created with RLS policies for residents and workers
  - Seed data applied (2026-05-16): property `10000000...0001` (Sunset Gardens), building, floor, unit 104, invite code `WELCOME104`
  - `verify_invite_code('WELCOME104', '10000000-0000-0000-0000-000000000001', '104')` returns `is_valid=true` ✓

- **Flutter mobile app** (`mobile/`)
  - Status: **VERIFIED** — compiles, runs on Chrome, all 6 dashboards load with real data, resident signup flow end-to-end confirmed.
  - Flutter SDK: `C:\Users\e159305\Apps\flutter\bin` (on user PATH, Flutter 3.41.9)
  - Entry: `main.dart` → `ValetApp` (MaterialApp + AppTheme.dark) → `AuthGate` → role-based screen
  - **Phase 1 redesign complete (2026-05-16)**:
    - Design tokens: `core/theme/app_colors.dart`, `core/theme/app_typography.dart`, `core/theme/role_theme.dart`, `core/theme/app_theme.dart`
    - Shared widgets: `core/widgets/glow_badge.dart`, `stat_tile.dart`, `skeleton_card.dart`, `role_hero_card.dart`, `primary_button.dart`, `role_bottom_nav.dart`
    - Auth screen redesigned: dark background, DM Sans font, emerald accent, `flutter_animate` staggered entry
    - Old files deleted: `core/brand_colors.dart`, `core/app_theme.dart`
    - New packages: `shadcn_flutter`, `flex_color_scheme`, `google_fonts`, `flutter_animate`, `rive`, `lottie`, `fl_chart`, `shimmer`, `gap`, `phosphor_flutter`, `cached_network_image`
    - 43 tests pass (1 pre-existing Supabase integration test requires live connection)
  - Key screens: SimpleAuthScreen, ResidentSignupScreen, ResidentDashboardScreen, WorkerDashboardScreen, ViolationReportScreen, PropertyManagerDashboardNewScreen, OwnerDashboardScreen, ManagerDashboardScreen, TodayComebacksScreen
  - **Compile fixes applied (2026-05-16)**:
    - `manager_dashboard_screen.dart`, `property_manager_dashboard_new.dart`, `owner_dashboard_screen.dart`: `.inFilter()` → `.filter('col', 'in', '(...)')` (postgrest v1.5.2 compat)
    - `manager_dashboard_screen.dart`, `property_manager_dashboard_new.dart`, `owner_dashboard_screen.dart`: `Future.wait([...])` → `Future.wait(<Future<dynamic>>[...])`
    - `violation_report_screen.dart`: removed `dart:io` import, switched to `uploadBinary` + `file.readAsBytes()` + `file.name` (Flutter web compat)
  - **Dashboard test results (2026-05-16)**:
    - ✅ Resident Dashboard — all tabs load, notifications, violations, profile
    - ✅ Worker Dashboard — shows assignment (Sunset Gardens), Clock In, Report Violation buttons
    - ✅ Property Manager Dashboard — 1 property, 1 unit, 1 resident, service window, notify buttons
    - ✅ Operations Manager Dashboard — Test Worker shown in assigned workers, 1 property, 1 worker
    - ✅ Owner Dashboard — loads with real portfolio data (3 properties, 1 resident, 100% activation)
    - ✅ Resident signup flow — full end-to-end: form → invite code validation → account creation → dashboard
  - **Bug fixes applied (2026-05-16 session 4)**:
    - `simple_auth_screen.dart`: wrapped Column in `Form(key: _formKey, ...)` — was missing, causing null crash on every sign-in attempt
    - `valet_app.dart`: added `'operations_manager'` case to `RoleHome` switch + import for `ManagerDashboardScreen` — was unreachable via real auth
    - Supabase DB: `ALTER TYPE user_role ADD VALUE 'operations_manager'` — enum was missing this value
  - **Test accounts** (all password `TestPass123!`):
    - `adam.grant824+res2@gmail.com` — resident, unit 104, Sunset Gardens
    - `adam.grant824+pm@gmail.com` — property_manager, user_properties row for Sunset Gardens
    - `adam.grant824+om@gmail.com` — operations_manager, user_properties row for Sunset Gardens
    - `adam.grant824+worker@gmail.com` — driver, worker_assignments row for Sunset Gardens

- **Supabase migrations** (`supabase/migrations/`)
  - Status: Applied to remote DB (done 2026-05-15 via SQL editor)
  - 001: base schema, 004: RLS, 005: invites + user_properties + notifications fix, 006: storage

- **Seed data**
  - `010_seed_invite_codes.sql` — provides invite code `WELCOME104` (not yet confirmed applied to remote)

- **Admin dashboard** (`admin_dashboard/`)
  - Status: Scaffolded but not validated against current DB schema

- **Stripe edge function** (`supabase/functions/stripe-webhook/`)
  - Status: Scaffold only — not deployed

## In Progress / Likely Active Work
- `main_simple.dart` — alternate entry point; purpose unclear, may be a dev artifact

## Known Issues
- `supabase_flutter` is pinned at v1.10.25 — v2 migration is a future breaking change (`.inFilter()` not available in v1; use `.filter('col', 'in', '(...)')` syntax)
- No `.env` file committed — new developers need to create `mobile/.env` manually with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Supabase email confirmation is currently **disabled** — re-enable when a transactional email provider is configured
- `flutter run -d chrome` opens a new system Chrome window each restart; use `flutter run -d web-server --web-port 8090` for Playwright-controlled testing

## Open Questions
- What is `main_simple.dart` used for — should it be removed?
- Is OneSignal token collection planned for Phase 1 or Phase 2?
- Does the admin dashboard target the same Supabase project?
- Flutter is not installed on this machine — where is it installed / which machine will be used for device testing?

## Resume Instructions
1. Read this file first, then `brain/next_steps.md`
2. `flutter run -d web-server --web-port 8090 --no-pub` from `mobile/` — serves at http://localhost:8090
3. Next focus: Phase 2 — OneSignal push notifications, Stripe webhook, Twilio SMS
