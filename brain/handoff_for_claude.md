# Relaxed Living Valet — Project Handoff (copy to Claude)

**Generated:** May 2026  
**Purpose:** Single document summarizing project state, chat decisions, and next steps for continuing work in Claude or another AI session.

---

## 1. What this project is

**Relaxed Living Valet** is a Flutter + Supabase app for apartment valet trash service (“Uber for apartments”).

- **Residents** sign up with invite codes, request comebacks, rate service, submit concerns.
- **Drivers/workers** run nightly routes, clock in/out, share GPS, report violations.
- **Property managers (PM)** see occupancy, billing (85% rule), invite codes, compliance.
- **Operations managers (OM)** run nightly ops, workforce timecards, live worker map.
- **Owner** sees portfolio financials, labor cost, and opens **Admin Portal** for setup.

**GitHub:** https://github.com/relaxedlivingvalet/valettrashmobile (branch `main`)

**Local dev:** http://localhost:8091 (Flutter web)

---

## 2. Tech stack

| Layer | Technology |
|-------|------------|
| App | Flutter 3.x, Dart, Material 3 |
| Backend | Supabase (Postgres, Auth, Realtime, Storage, Edge Functions) |
| Payments | Stripe (scaffold only — webhooks not live) |
| Auth routing | `valet_app.dart` → `AuthGate` → `RoleHome` polls `users.role` |

**Entry:** `mobile/lib/main.dart` loads `mobile/.env` (SUPABASE_URL, SUPABASE_ANON_KEY).

**Never put `service_role` in the Flutter app.**

---

## 3. Supabase

| Item | Value |
|------|-------|
| Project name | relaxedl-living |
| Project ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| Dashboard | https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft |

### Migrations applied on hosted (007–011)
- 007 service_requests + owner role enum
- 008 resident comeback balance, preferred_time
- 009 staff_invites (PM/OM/driver self-signup)
- 010 property billing metrics ($/door, 85% min)
- 011 billing_total_doors, billing_occupied_doors

### Migrations in repo but NOT confirmed applied on hosted (012–014)
Apply in order in SQL editor:
1. `supabase/migrations/012_workforce_labor.sql` — hourly_rate, clock_events RLS, set_worker_hourly_rate RPC
2. `supabase/migrations/013_unify_owner_role.sql` — relaxedlivingtx@gmail.com → role `owner`
3. `supabase/migrations/014_launch_rls_hardening.sql` — re-enable RLS, is_owner_admin(), satellite table policies

After 014, run: `supabase/tests/rls_role_smoke.sql`

**Known blocker:** ~19 public tables had RLS disabled on hosted DB. Migration 014 addresses this.

---

## 4. How to run locally

```powershell
cd mobile
flutter pub get
flutter run -d web-server --web-port 8091 --no-pub
```

Open http://localhost:8091 — hard refresh or `R` after code changes.

Release builds (not debug):
```powershell
flutter build web --release
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS — needs Mac
```

---

## 5. User roles and dashboards

| Role (DB) | Login button | Screen |
|-----------|--------------|--------|
| resident | Resident | ResidentDashboardScreen |
| driver | Staff | WorkerDashboardScreen |
| property_manager | Staff | PropertyManagerDashboardNewScreen |
| operations_manager | Staff | ManagerDashboardScreen |
| owner | Staff | OwnerDashboardScreen |
| super_admin | Staff | Same as owner (legacy enum) |

**Owner ≡ super_admin:** Both route to Owner dashboard. Admin Portal is NOT a separate login — open from Owner → top bar **Admin Portal** or More → Admin Portal. Admin has top bar **Owner Dashboard** to switch back (same session, no re-login).

---

## 6. Test credentials (DEV ONLY — rotate before production)

App: http://localhost:8091

| Email | Password | Role |
|-------|----------|------|
| relaxedlivingtx@gmail.com | RelaxedLiving2026! | owner (Staff login) |
| adam.grant824+om@gmail.com | TestPass123! | operations_manager |
| adam.grant824+worker@gmail.com | TestPass123! | driver |
| adam.grant824+pm@gmail.com | TestPass123! | property_manager |
| adam.grant824+res2@gmail.com | TestPass123! | resident (Sunset Gardens unit 104) |

Test property: Sunset Gardens — ID `10000000-0000-0000-0000-000000000001`  
Test unit: 104 — invite code `WELCOME104`

Optional owner alias: relaxedlivingtx+owner@gmail.com (create in Supabase Auth first)

---

## 7. Major features built (chat + dev history)

### Auth & onboarding
- Resident signup: invite code + property + unit via RPCs `verify_invite_code`, `claim_invite_code`
- Staff signup: staff invite codes → `register_staff_with_invite` RPC
- **Bug fixed:** Staff signup landed on resident UI — race between signUp and RPC; fix: `fetchUserRole()` polls in `user_profile.dart`, RoleHome no longer defaults to resident on null

### Owner / Admin
- Unified owner login (owner + super_admin → OwnerDashboardScreen)
- Two-way quick switch: Owner ↔ Admin Portal (top bars + Admin Tools tile)
- Owner Financials: contract revenue, MRR, revenue/door, labor estimates, Stripe payout list, CSV export
- Admin Portal: users, properties, residents, concerns, tools (invite codes, staff invites, billing rates, assignments)

### Property manager
- Properties tab: occupied/vacant per unit, invite codes, 85% billable banner, est monthly bill, Export unit codes CSV
- Dashboard: pickup SLA, satisfaction, pending comebacks (not resident service requests)

### Billing (85% rule)
- Billable doors = max(occupied, ceil(total × 85%))
- Admin: Property Billing Rates — enter total doors, occupied, $/door → auto calc
- Helper: `mobile/lib/core/billing/property_billing.dart`
- Migrations: 010, 011

### Workforce / labor
- Worker: clock in/out → `clock_events`; share location → `worker_locations`; Earnings screen
- OM: Workforce & Timecards (`OmWorkforceScreen`), Live Worker Map
- Owner: labor $ from hours × rate; Manage rates (`OwnerWorkforceScreen`); RPC `set_worker_hourly_rate`
- Helper: `mobile/lib/core/workforce/clock_hours.dart`
- Migration: 012

### Resident
- Comebacks: 1 free/month (no rollover); banked credits roll over; paid packs 1/$5, 3/$14, 5/$20
- Worker status badge: ON DUTY vs SCHEDULED from latest clock_events per property
- Extra services + service requests inbox (owner/admin)
- Support/concerns tab

### Resident invite workflow
- Super admin generates codes → stored in DB → PM sees on Properties tab → PM exports CSV → residents use Resident signup
- Doc: `brain/resident_invite_workflow.md`
- Codes are NOT auto-emailed to PM

---

## 8. Key files map

```
mobile/lib/
  main.dart, valet_app.dart
  core/billing/property_billing.dart
  core/workforce/clock_hours.dart
  core/auth/user_profile.dart
  features/owner/screens/owner_dashboard_screen.dart
  features/owner/screens/owner_workforce_screen.dart
  features/owner/widgets/owner_admin_switch_bar.dart
  features/admin/screens/admin_dashboard_screen.dart
  features/admin/screens/admin_property_billing_screen.dart
  features/manager/screens/property_manager_dashboard_new.dart
  features/manager/screens/manager_dashboard_screen.dart
  features/manager/screens/om_workforce_screen.dart
  features/manager/screens/om_worker_map_screen.dart
  features/worker/screens/worker_dashboard_screen.dart
  features/resident/screens/resident_dashboard_screen.dart

supabase/migrations/   (001–014, apply in order)
supabase/tests/rls_role_smoke.sql

brain/
  current_state.md      — resume here each session
  go_live_checklist.md  — phased launch plan
  next_steps.md         — active todos
  test_credentials.md
  resident_invite_workflow.md
  decisions.md, change_log.md, architecture.md
```

---

## 9. Business rules (important)

### PM billing
- Default $25/door/month, 85% minimum occupancy for billable doors
- billable_doors = max(occupied, ceil(total × 0.85))
- Owner revenue/door = (contract + MRR + paid invoices + paid comebacks) ÷ billable doors

### Comebacks
- 1 free per calendar month per resident (no rollover)
- Purchased balance on resident_units.purchased_comeback_balance rolls over
- Stripe checkout for paid comebacks still placeholder

### Workforce
- OM = operational view (who’s on duty, hours, map)
- Owner = financial view (hours × hourly rate, edit rates)
- Steps/pedometer NOT built

---

## 10. Known issues and blockers

| Issue | Status |
|-------|--------|
| RLS off on many hosted tables | Fix in migration 014 — apply manually |
| Migrations 012–014 not applied on hosted | Pending — MCP timed out May 27 |
| Stripe Connect webhooks | Not live — contractor_payouts manual/placeholder |
| Paid comeback checkout | Placeholder |
| Worker GPS on native | Uses dart:html (web only) — need geolocator for stores |
| CSV export on native | dart:html — need share_plus |
| iOS signing | Needs Mac + Apple Developer $99/yr |
| supabase_flutter v1 → v2 | Backlog |
| Test passwords in repo docs | Rotate before production |

---

## 11. Readiness estimate (May 2026)

| Milestone | Status |
|-----------|--------|
| Sales demo (web) | Ready now |
| Limited pilot (1–2 properties) | ~2–4 weeks after RLS + QA |
| App Store / Play Store (hardened) | ~4–8 weeks |

---

## 12. Ordered next steps (go-live)

### Week 1 — Security (do first)
1. Apply migrations 012, 013, 014 on Supabase SQL editor
2. Run rls_role_smoke.sql — zero tables without RLS
3. Full role QA after RLS (owner, resident, worker, PM, OM)
4. Secrets: anon key only in app; rotate if exposed

### Week 1–2 — Environments
5. Create staging + production Supabase projects (separate from dev)
6. Production auth: Site URL, redirect URLs, email provider (Resend/SendGrid)
7. Remove test accounts from production

### Week 2 — Legal (before real residents)
8. Privacy Policy URL (required for stores)
9. Terms of Service
10. Property management contracts + worker agreements
11. LLC/insurance (business protection — consult lawyer)

### Week 3–4 — Pilot
12. Onboard 1 property end-to-end (resident_invite_workflow.md)
13. Error monitoring (Sentry/Crashlytics)
14. Support runbook

### Week 4–6 — Stores
15. flutter build appbundle / ipa (release)
16. Play Internal testing → TestFlight
17. Native GPS + CSV fixes before broad mobile rollout

Full detail: `brain/go_live_checklist.md`

---

## 13. Recent git commits (main)

```
87b3477 Record go-live launch commit hash in brain
2f0c9b8 Start go-live readiness: checklist and RLS hardening migration
8b5b8aa Add two-way Owner/Admin dashboard switching
eb29777 Unify owner and super_admin into one business-owner login
401b13e Add OM timecards and owner labor estimates from clock events
48ec1cf Billing door counts UI (011)
b41ae6a Owner financials, PM billing, invite playbook
2a996f7 Staff invite self-signup
```

---

## 14. Chat session topics covered (Cursor)

1. Owner login — unified owner/super_admin, dedicated test account
2. Workforce — OM timecards, owner labor $, clock_events, hourly rates
3. Owner ↔ Admin two-way navigation without separate passwords
4. Go-live readiness assessment (~80% demo, ~65% pilot, ~45–60% production)
5. Ordered launch playbook (legal, RLS, pilot, stores)
6. Brain docs updated and pushed to GitHub throughout

---

## 15. Instructions for Claude (or next AI)

When continuing this project:

1. Read first: `brain/current_state.md`, `brain/go_live_checklist.md`, `brain/next_steps.md`
2. Do NOT commit unless user asks
3. Apply Supabase migrations in order; verify with smoke test
4. Owner test login: relaxedlivingtx@gmail.com / RelaxedLiving2026! (Staff)
5. Primary blocker for pilot: RLS migration 014 on hosted DB
6. Preserve existing patterns: PropertyBilling, ClockHours, RoleHome polling
7. PM does NOT manage workforce/payroll — that's OM (ops) and Owner (money)

---

## 16. Repo brain system

This repo uses a "brain" folder for persistent AI context:
- `brain/current_state.md` — where to resume
- `brain/next_steps.md` — active todos
- `brain/change_log.md` — session history
- `brain/decisions.md` — architectural decisions
- `.cursor/rules/` — coding standards

Update brain files after meaningful work.

---

END OF HANDOFF
