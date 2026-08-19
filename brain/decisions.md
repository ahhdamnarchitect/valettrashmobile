# Decisions Log

## Format
- Date | Decision | Reason | Alternatives Considered | Impact

---

### 2026-05-15
- **Decision**: Dropped and recreated `invite_codes` table during migration 005.
- **Reason**: Legacy table had an incompatible schema (`invite_code TEXT` column name and `unit_number TEXT` instead of `unit_id UUID FK`). The existing 3 seed rows were expendable.
- **Alternatives Considered**: ALTER TABLE to rename/retype columns (would have been messier with FK constraints).
- **Impact**: Old invite codes were cleared. Seed data must be re-applied via `010_seed_invite_codes.sql`.

### 2026-05-15
- **Decision**: Dropped and recreated `verify_invite_code` and `claim_invite_code` functions during migration 005.
- **Reason**: Old function signatures had a different return type that conflicted with the new schema. PostgreSQL won't let you `CREATE OR REPLACE` a function with a different return type.
- **Alternatives Considered**: Use a different function name — rejected because the Flutter app already calls these by name.
- **Impact**: Both RPCs now match the new `invite_codes` schema and are callable by `anon` + `authenticated`.

### 2026-05-15
- **Decision**: `violations.pickup_id` made nullable.
- **Reason**: Workers need to file violations without an associated pickup (e.g., during property walkthroughs). The original NOT NULL constraint was too restrictive.
- **Alternatives Considered**: Keep NOT NULL and require a dummy pickup record — rejected as data pollution.
- **Impact**: Violation reports from `ViolationReportScreen` can now be created without a pickup context.

### 2026-05-15
- **Decision**: `notifications.user_id` made nullable; added `property_id`, `sender_id`, `is_active`, `metadata` columns.
- **Reason**: Notifications needed to support two modes: (1) direct to a user, (2) broadcast to all residents of a property. Original schema only supported direct targeting.
- **Alternatives Considered**: Separate table for broadcast notifications — rejected to keep queries simple.
- **Impact**: RLS policy now covers both modes. `SimpleNotificationSenderScreen` can target a property.

### 2026-05-15
- **Decision**: Installed Repo OS (brain/ + .cursor/rules/ + cursor-os/) structure.
- **Reason**: Project needs persistent memory for resumable AI-assisted development sessions.
- **Alternatives Considered**: Ad-hoc notes, no shared memory system.
- **Impact**: Future sessions should open brain files first and have consistent context.

### (Original — pre-migration)
- **Decision**: Use SECURITY DEFINER RPCs for invite code verification and claiming.
- **Reason**: `invite_codes` table is locked down with RLS (`FOR SELECT USING (false)`). The only access is through controlled functions that validate the caller's identity.
- **Alternatives Considered**: Give authenticated users SELECT on invite_codes — rejected due to code enumeration risk.
- **Impact**: `verify_invite_code(code, property_id, unit_number)` and `claim_invite_code(invite_id, user_id)` are the only paths to use an invite.

### 2026-05-18
- **Decision**: Resident comeback quota — **1 free per calendar month** (no rollover); **purchased** credits on `resident_units.purchased_comeback_balance` **do roll over**; paid packs **1/$5, 3/$14, 5/$20**.
- **Reason**: Client business rules for valet trash comeback pickups.
- **Alternatives Considered**: Property-level `free_comeback_pickups_per_month` only — rejected for resident UX in favor of fixed app constant `kMonthlyFreeComebacks = 1`.
- **Impact**: `ResidentComebackRequestScreen` consumes free → banked → $5 single; `BuyExtraPickupsSection` increments balance (Stripe TBD).

### 2026-05-18
- **Decision**: Resident worker status from **`clock_events`** (latest event per property), not `nightly_runs.status`.
- **Reason**: Status should reflect when the assigned worker clocks in.
- **Alternatives Considered**: Keep polling `nightly_runs` — rejected per client spec.
- **Impact**: Header shows ON DUTY vs SCHEDULED; requires worker to use clock in on worker dashboard.

### 2026-05-19
- **Decision**: Property manager **billable doors** = `max(occupied, ceil(total_units × 0.85))`; stored defaults on `properties.minimum_billable_occupancy_percent` and `monthly_fee_per_door`.
- **Reason**: Client contract — PM pays for at least 85% of doors regardless of actual move-ins.
- **Alternatives Considered**: Bill only occupied units — rejected per client.
- **Impact**: `PropertyBilling` helper; PM Properties tab + owner Financials; migration `010`.

### 2026-05-19
- **Decision**: Resident invite codes flow **super admin → Supabase → PM read-only**; PM exports CSV for distribution; residents use **Resident** signup (not Staff).
- **Reason**: Clear separation of staff vs resident onboarding; no push/email pipeline yet.
- **Impact**: `brain/resident_invite_workflow.md`; PM export; admin `use_count` column fix.

### 2026-08-18
- **Decision**: In-person apartment demos use **TestFlight** after a Mac IPA build; until then, iPad Safari on the PC’s LAN IP. Do not treat the marketing site as the app.
- **Reason**: Apple requires macOS/Xcode; `localhost` only works on the machine running Flutter; relaxlivingvalet.com is marketing.
- **Impact**: Owner needs Apple Developer + Mac; Privacy/Terms on the site before store review.

### 2026-08-13
- **Decision**: Resident payments use **Stripe Checkout** via Edge Functions; secret key never in the Flutter app; credits applied only on webhook `checkout.session.completed`. Existing Stripe accounts are **not** auto-connected.
- **Reason**: PCI-safe, matches existing pack prices, works on web demo (`localhost:8091`).
- **Impact**: `015_stripe_payments.sql`, `create-checkout-session`, updated `stripe-webhook`; owner must set Stripe secrets.

### 2026-07-12
- **Decision**: Go-live **Step 1 = legal/business foundation** (entity, insurance, Privacy Policy, Terms, property/worker agreements) before or parallel to technical hardening; first technical action remains migrations `012`→`014`.
- **Reason**: Protect owner liability and store-compliance before real resident data or payments.
- **Impact**: `brain/go_live_checklist.md`, `brain/next_steps.md` ordered Steps 1–6.

### 2026-05-19
- **Decision**: **Go-live phased** — demo now → security sprint (RLS 014) → pilot → stores; tracked in `brain/go_live_checklist.md`.
- **Reason**: Client wants operational launch with security, not just feature-complete UI.
- **Impact**: Migration `014_launch_rls_hardening.sql`, `rls_role_smoke.sql`, Phase 0–4 checklist.

### 2026-05-19
- **Decision**: Keep **Owner** and **Admin Portal** as separate screens with **two-way quick switching** (Owner → Admin and Admin → Owner).
- **Reason**: Preserve screen separation while removing navigation friction during live operations and setup tasks.
- **Alternatives Considered**: Merge dashboards into one screen — rejected to avoid overloading a single UI.
- **Impact**: Added top switch bars and admin Tools switch tile; no auth/email/password changes required.

### 2026-05-19
- **Decision**: **`owner` ≡ `super_admin`** — one business-owner login tier; both route to `OwnerDashboardScreen`; Admin Portal linked from Owner → More.
- **Reason**: Client treats company owner as single role; Financials + system setup without two separate logins.
- **Impact**: `relaxedlivingtx@gmail.com` role `owner`; migration `013`; `brain/test_credentials.md`.

### 2026-05-19
- **Decision**: **Workforce ops on OM dashboard; labor $ on Owner** — same `clock_events` data, different UI.
- **Reason**: OM runs nightly ops (who is on duty, hours, map); Owner approves pay and sees cost vs revenue.
- **Alternatives Considered**: Single combined admin screen — rejected; PM does not manage payroll.
- **Impact**: `OmWorkforceScreen`, `OwnerWorkforceScreen`, `clock_hours.dart`; steps tracking deferred.

### 2026-05-19
- **Decision**: `RoleHome` **polls** `users.role` after auth instead of defaulting to `resident` on first null row.
- **Reason**: Race between `auth.signUp` and `register_staff_with_invite` left staff users on resident dashboard.
- **Impact**: `fetchUserRole()` in `user_profile.dart`.

### 2026-05-18
- **Decision**: Resident bottom nav uses **`IndexedStack`**; service grids use **fixed-height** `ExtraServicesGrid` instead of `shrinkWrap` `GridView` inside `ListView`.
- **Reason**: Tab switches caused extra-service tiles to paint across the screen.
- **Alternatives Considered**: Single shared grid only on Extra Services tab — partially adopted (compact grid on Home + full tab).
- **Impact**: Stable layout; slightly more code in `extra_services_grid.dart`.

### 2026-05-18
- **Decision**: Extra service requests require **date and time**; message optional with server default text.
- **Reason**: Submit failures and incomplete scheduling; `message` column is NOT NULL in DB.
- **Impact**: `service_requests.preferred_time` (migration 008); owner/admin inbox shows richer requests.

### (Original — pre-migration)
- **Decision**: Role routing at the app level — `RoleHome` queries `users.role` and pushes the correct screen.
- **Reason**: Single Flutter codebase serves four distinct user types. Simpler than separate builds.
- **Alternatives Considered**: Separate apps per role — rejected as overkill for Phase 1.
- **Impact**: All roles share one app binary. Any role confusion would be caught at the `users.role` query.
