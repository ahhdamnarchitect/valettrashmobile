# Handoff — Relaxed Living Valet (for Claude / ChatGPT / other AI)

**Updated:** 2026-08-10  
**Repo:** https://github.com/relaxedlivingvalet/valettrashmobile (`main`)  
**Local path:** `C:\Users\WeLovePQ\Desktop\CascadeProjects\windsurf-project`  
**App (dev):** http://localhost:8091  

Copy this whole file into a new Claude or ChatGPT chat to resume work. Prefer also reading live brain files in the repo when coding in Cursor.

---

## How to use this handoff

1. Paste this document as the first message (or system context).
2. Ask the AI to: read `brain/current_state.md`, `brain/next_steps.md`, `brain/go_live_checklist.md` if it has repo access.
3. State the goal (e.g. “apply RLS migrations”, “wire Stripe”, “demo property setup”).
4. Do **not** invent schema — use migrations in `supabase/migrations/`.
5. Do **not** put `service_role` in the Flutter client — anon key only.

---

## What this product is

**Relaxed Living Valet** — valet trash for apartment complexes (“Uber for apartments”). Residents put bags out; drivers pick up nightly. Flutter app + Supabase backend. Roles:

| Role (DB) | Screen | Theme |
|---|---|---|
| `resident` | ResidentDashboardScreen | Dark |
| `driver` | WorkerDashboardScreen | Dark |
| `operations_manager` | ManagerDashboardScreen (workforce, map) | Dark |
| `property_manager` | PropertyManagerDashboardNewScreen | Light |
| `owner` / `super_admin` | OwnerDashboardScreen (same login tier) | Light |

Admin Portal (`AdminDashboardScreen`) is **not** a separate login — open from Owner via top switch bar or More → Admin Portal. Switch back with Admin top bar → Owner Dashboard.

---

## Stack

- **Flutter** (mobile + web), Material 3, `supabase_flutter` v1.x
- **Supabase** Auth + Postgres + Storage + (planned) Edge Functions
- **Stripe Checkout** — packs + paid comeback; webhook fulfillment in repo; **secrets not set until owner adds keys** (`brain/stripe_setup.md`)
- Brain / Repo OS: `brain/` + `.cursor/rules/`

---

## Supabase

| Item | Value |
|---|---|
| Project | relaxedl-living |
| Ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| Dashboard | https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft |

Env (local): `mobile/.env` with `SUPABASE_URL` + `SUPABASE_ANON_KEY` (see `mobile/.env.example`).

### Migrations status

| File | Status on hosted |
|---|---|
| `007`–`011` | Applied live |
| `012_workforce_labor.sql` | **Pending apply** (in repo) |
| `013_unify_owner_role.sql` | **Pending apply** (in repo) |
| `014_launch_rls_hardening.sql` | **Pending apply** (in repo) |
| `015_stripe_payments.sql` | **Applied hosted** Aug 13 |

Apply **012 → 013 → 014** in SQL editor, then run `supabase/tests/rls_role_smoke.sql`.

### Billing rules (implemented)

- Billable doors = `max(occupied, ceil(total × 0.85))` (default 85%)
- Fields: `monthly_fee_per_door`, `minimum_billable_occupancy_percent`, `billing_total_doors`, `billing_occupied_doors`
- Helper: `mobile/lib/core/billing/property_billing.dart`
- Admin: Tools → Property Billing Rates

### Comeback rules (implemented)

- 1 free comeback / calendar month (no rollover)
- Purchased credits roll over on `resident_units.purchased_comeback_balance`
- Packs: 1/$5, 3/$14, 5/$20 — checkout still placeholder

---

## Key product decisions (do not reverse without asking)

1. **`owner` ≡ `super_admin`** — both route to Owner dashboard; Admin via switch, not separate password.
2. **Resident invite flow:** Owner/Admin generates codes → DB → PM sees/exports CSV → residents use **Resident** signup (not Staff). Playbook: `brain/resident_invite_workflow.md`.
3. **Staff invite:** separate `staff_invites` + RPCs for PM / OM / driver.
4. **Workforce:** OM = timecards/map; Owner = labor $ (hours × hourly_rate). Steps/pedometer deferred.
5. **Worker on-duty badge** for residents = latest `clock_events` (not `nightly_runs`).
6. **RoleHome** polls `fetchUserRole()` after signup (avoid defaulting to resident during staff register race).
7. Go-live: legal/business → RLS → QA → staging/prod → pilot → stores. Checklist: `brain/go_live_checklist.md`.

---

## Test credentials (dev only — do not ship in production)

Sign in with **Staff** for owner/staff; **Resident** for residents.

| Email | Password | Role |
|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | owner |
| `adam.grant824+om@gmail.com` | `TestPass123!` | operations_manager |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | driver |
| `adam.grant824+pm@gmail.com` | `TestPass123!` | property_manager |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | resident |

| Test data | Value |
|---|---|
| Property | Sunset Gardens |
| Unit | 104 |
| Invite code | `WELCOME104` |

Full list: `brain/test_credentials.md`

---

## Run the app

```powershell
cd C:\Users\WeLovePQ\Desktop\CascadeProjects\windsurf-project\mobile
flutter pub get
flutter run -d web-server --web-port 8091 --no-pub
```

Open http://localhost:8091 — hard refresh or `R` after code changes.

---

## Important files

| Area | Paths |
|---|---|
| Entry / routing | `mobile/lib/main.dart`, `valet_app.dart`, `core/auth/user_profile.dart` |
| Billing | `core/billing/property_billing.dart`, `admin_property_billing_screen.dart` |
| Workforce | `core/workforce/clock_hours.dart`, `om_workforce_screen.dart`, `owner_workforce_screen.dart` |
| Owner ↔ Admin switch | `owner/widgets/owner_admin_switch_bar.dart` |
| Migrations | `supabase/migrations/012`–`014_*.sql` |
| Plans | `brain/go_live_checklist.md`, `brain/next_steps.md`, `brain/current_state.md` |

---

## Owner status (human)

- **LLC:** done
- **Bank account:** needed (for Stripe)
- **Privacy Policy / Terms public URLs:** still needed
- **Insurance / property contracts:** recommended before real signed complexes
- **Demo readiness:** app feature-complete enough for apartment **web demos** now
- **Production/store:** blocked on RLS apply, policies, Stripe, release builds

---

## Ordered next work (priority)

### For apartment demos (this month)
1. Rehearse all roles on localhost:8091
2. Polish one demo property (doors, rates, invite codes)
3. Publish Privacy + Terms URLs (even simple)
4. Open business bank → Stripe account (test mode OK for demos of UI)
5. Apply migrations 012→014 + RLS smoke test

### For real pilot / charging
6. Staging + prod Supabase projects; production auth URLs + email provider
7. Set Stripe secrets + deploy functions (`brain/stripe_setup.md`); Connect payouts later
8. Pilot 1 property via `brain/resident_invite_workflow.md`
9. Liability insurance + signed property/worker agreements

### For App Store / Play
10. `flutter build appbundle --release` / `ipa` (iOS needs Mac + Apple Dev)
11. Store listings, Data safety / App Privacy labels
12. Native GPS (`geolocator`), CSV `share_plus`, push later

---

## Known gaps / risks

- Hosted DB may still have **RLS off** on many tables until 014 applied
- Stripe paid flows = placeholders; Financials read DB rows only
- Worker location / CSV export use **web** (`dart:html`) paths
- `supabase_flutter` still on v1
- Site URL still localhost-oriented for auth emails
- Never commit secrets; rotate if exposed

---

## Repo OS rules (Cursor)

Before meaningful work: read `brain/project_context.md`, `architecture.md`, `current_state.md`, `decisions.md`, `next_steps.md`.  
After meaningful work: update `current_state.md`, append `change_log.md`, update `next_steps.md`, `decisions.md` if needed.

---

## Suggested first prompt for Claude / ChatGPT

> You are helping finish Relaxed Living Valet (Flutter + Supabase). Read the handoff above. Current goal: [APPLY MIGRATIONS 012-014 / DEMO PROPERTY SETUP / STRIPE PLAN / PRIVACY POLICY DRAFT]. Follow existing patterns; do not invent new roles or billing rules. Prefer minimal targeted changes. Update brain files when done.

---

## Recent notable commits (approx)

| Commit | What |
|---|---|
| `5e86663` | Ordered go-live playbook + Step 1 legal in brain |
| `2f0c9b8` | Go-live checklist + migration 014 RLS hardening |
| `8b5b8aa` | Owner ↔ Admin two-way quick switch |
| `401b13e` | OM timecards + owner labor estimates |
| `eb29777` | Unify owner + super_admin login |

Always `git pull` and check `git log` for latest.
