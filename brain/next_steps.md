# Next Steps

## Completed (2026-05-16)
- [x] `mobile/.env` written with Supabase URL + anon key
- [x] Seed data applied: property `10000000...0001`, unit `104`, invite code `WELCOME104`
- [x] `verify_invite_code` RPC confirmed returning `is_valid=true` for `WELCOME104`
- [x] Flutter added to PATH (`C:\Users\e159305\Apps\flutter\bin`)
- [x] `flutter config --enable-web` — done
- [x] App compiles and runs: `flutter run -d chrome`
- [x] Resident signup end-to-end verified (Sunset Gardens → unit 104 → WELCOME104 → dashboard)
- [x] All 6 dashboards confirmed loading with real Supabase data

## Completed (2026-05-16 session 4)
- [x] Fixed `SimpleAuthScreen` Form widget bug (null crash on every sign-in attempt)
- [x] Fixed `AuthGate` routing — added `operations_manager` case + import for `ManagerDashboardScreen`
- [x] Added `operations_manager` to `user_role` DB enum
- [x] Created PM, OM, and worker test accounts with proper `user_properties`/`worker_assignments` rows
- [x] Verified all 5 role dashboards with real Supabase data (PM, OM, Worker, Resident, Owner)

## Completed (2026-05-16 — Phase 1 Redesign)
- [x] Installed redesign package stack (shadcn_flutter, flex_color_scheme, flutter_animate, shimmer, etc.)
- [x] Built design token layer: AppColors, AppTypography (DM Sans), RoleTheme, AppTheme.dark
- [x] Built shared widget library: GlowBadge, StatTile, SkeletonCard, RoleHeroCard, PrimaryButton, RoleBottomNav
- [x] Wired dark theme via MaterialApp + flex_color_scheme
- [x] Redesigned SimpleAuthScreen with dark fields, emerald accent, flutter_animate entry animations
- [x] 43 unit/widget tests passing; all committed across 12 commits

## Now (Phase 2 — Screen Redesigns)
- [ ] Write `docs/superpowers/plans/2026-05-16-redesign-phase2-screens.md`
- [ ] Redesign ResidentDashboardScreen using RoleHeroCard + StatTile + RoleBottomNav
- [ ] Redesign WorkerDashboardScreen using RoleHeroCard + SkeletonCard + RoleBottomNav
- [ ] Redesign PropertyManagerDashboardNewScreen using RoleHeroCard + StatTile + RoleBottomNav
- [ ] Redesign ManagerDashboardScreen (Operations Manager) using same widget system
- [ ] Redesign OwnerDashboardScreen using RoleHeroCard + StatTile grid

## Next
- [ ] Confirm admin_dashboard targets the correct Supabase project and schema
- [ ] Clarify `main_simple.dart` — remove it or document its purpose
- [ ] Test ViolationReportScreen: photo pick → upload to `violations/workers/<uid>/...` → insert violations row

## Phase 2 Backlog
- [ ] Wire up OneSignal push notifications (collect token on login, store in users table or dedicated table)
- [ ] Deploy Stripe webhook edge function: `supabase functions deploy stripe-webhook` + set `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET` secrets
- [ ] Twilio SMS integration for pickup reminders
- [ ] Mapbox route mapping for WorkerDashboardScreen
- [ ] Stripe Connect for contractor payouts

## Blocked / Waiting
- Stripe integration blocked on Stripe account setup and webhook secret
- OneSignal blocked on OneSignal app ID / account setup

## Suggested Improvements
- [ ] Upgrade `supabase_flutter` from v1.10.25 to v2 (breaking change — plan carefully)
- [ ] Add a `.env.example` file so new developers know required variables
- [ ] Add integration tests for the invite code flow
- [ ] Consider adding `supabase db pull` to CI to detect schema drift
