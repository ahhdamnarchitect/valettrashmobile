# Handoff — Relaxed Living Valet (for Claude / ChatGPT / other AI)

**Updated:** 2026-08-21  
**Repo:** https://github.com/relaxedlivingvalet/valettrashmobile (`main`)  
**Local path:** `C:\Users\WeLovePQ\Desktop\CascadeProjects\windsurf-project`  
**App (dev):** http://localhost:8091 (PC only; iPad same Wi-Fi → `http://<PC-IPv4>:8091`)  
**Marketing site:** https://relaxedlivingvalet.com (not the Flutter app)  

Copy this whole file into a new Claude or ChatGPT chat to resume work. Prefer also reading live brain files in the repo when coding in Cursor.

---

## How to use this handoff

1. Paste this document as the first message (or system context).
2. Ask the AI to: read `brain/current_state.md`, `brain/next_steps.md`, `brain/go_live_checklist.md` if it has repo access. For **sales/pricing** questions it should read `brain/sales/offer.md` first — that is the source of truth for what the property pays, what residents pay, and the contract terms.
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
| `property_manager` | PropertyManagerDashboardNewScreen (apartment office, not RLV owner) | Light |
| `owner` / `super_admin` | OwnerDashboardScreen (Relaxed Living / you) | Light |

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
| Ref | `immiejqvnucndjspacwv` |
| Region | AWS us-east-2 |
| Dashboard | https://supabase.com/dashboard/project/immiejqvnucndjspacwv |

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
- Packs: 1/$5, 3/$14, 5/$20 — Checkout + webhook **deployed**; Stripe secrets still owner action (`brain/stripe_setup.md`)

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
| Plans | `brain/go_live_checklist.md`, `brain/next_steps.md` (**START HERE box at top**), `brain/current_state.md` |
| Owner's guide | `HANDOFF_FOR_REGGIE.md` (repo root) — plain-English steps, no code |
| **Sales** | `brain/sales/offer.md` (pricing source of truth), `sales-script.md`, `pitch-practice.md`, `roleplay-project-instructions.txt`, `call-card.html` |

---

## Selling the service — `brain/sales/` (added 2026-08-21)

Separate from the app. **`offer.md` is the source of truth for pricing and terms** — read it
before quoting any number, and change it there first, then propagate.

- **Model:** the property pays RLV **$15–18/door/month**; the property bills its own residents
  **$25–35** and keeps the spread. That spread is why a property manager says yes.
- **Contracts:** month-to-month (30-day out, no fee) and 36-month (liquidated damages, 10%/yr
  escalator). The month-to-month is the strongest asset in the offer — no national matches it.
- **Files:** `offer.md`, `sales-script.md` (walk-in + cold-call spines, objections),
  `pitch-practice.md` + `roleplay-project-instructions.txt` (ChatGPT-voice practice partner),
  `call-card.html` (the "Breezeway Board" tap-through card — **each person publishes their own
  artifact copy**; the prompt to do that is in the START HERE box of `next_steps.md`).
- **Do not claim** any property count or reference (there are none yet), or any Yardi / RealPage /
  Entrata integration — we are ineligible to build one, see `decisions.md` (2026-08-21).
- ⚠️ The script's **$18 / $15 split is Adam's recommendation, not Reggie's confirmed number.**

---

## Owner status (human)

- **LLC:** done
- **Bank account:** needed (for Stripe)
- **Privacy Policy / Terms public URLs:** still needed on https://relaxedlivingvalet.com
- **Insurance / property contracts:** recommended before real signed complexes
- **Demo readiness:** web demos now; iPad Safari via LAN IP; TestFlight needs Mac
- **Production/store:** blocked on RLS apply, Privacy/Terms, Stripe secrets, Mac IPA

---

## Ordered next work (priority)

### Do first
0. 🔴 **Run migration `20260516000032_correct_monthly_fee_per_door_default.sql`** on the hosted
   project. The per-door contract rate defaulted to `$25.00`, which is the *resident* price, not
   the rate a property pays us ($15–18). Until it runs, the live DB quotes every new property
   ~$7–10/door too high. Repo + provision path + Flutter fallback are already corrected.

### For apartment demos (this month)
1. Rehearse all roles on localhost:8091; iPad = same Wi-Fi + PC LAN IP (not localhost, not the marketing site)
2. Polish one demo property (doors, rates, invite codes)
3. Publish Privacy + Terms on https://relaxedlivingvalet.com
4. Paste Stripe test secrets + webhook (`brain/stripe_setup.md`); existing Stripe account is not auto-linked
5. Apply migrations 012→014 + RLS smoke test (Advisor currently flags RLS off)
6. For a downloadable iPad app: Apple Developer + Mac + Xcode → TestFlight (Windows cannot build IPA)

### For real pilot / charging
7. Staging + prod Supabase projects; production auth URLs + email provider
8. Stripe live keys after bank; Connect payouts later
9. Pilot 1 property via `brain/resident_invite_workflow.md`
10. Liability insurance + signed property/worker agreements

### For App Store / Play
11. `flutter build appbundle --release` / `ipa` (iOS needs Mac + Apple Dev); TestFlight before public App Store
12. Store listings, Data safety / App Privacy labels
13. Native GPS (`geolocator`), CSV `share_plus`, push later

---

## Known gaps / risks

- Hosted DB still has **RLS off** on core tables until 014 applied (Supabase Advisor ~24 critical)
- Stripe Checkout/webhook deployed; **secrets not set**; Financials read DB rows; Connect not live
- Worker location / CSV export use **web** (`dart:html`) paths
- `supabase_flutter` still on v1
- Auth Site URL still localhost-oriented; marketing site is relaxedlivingvalet.com
- Never commit secrets; rotate if exposed

---

## Repo OS rules (Cursor)

Before meaningful work: read `brain/project_context.md`, `architecture.md`, `current_state.md`, `decisions.md`, `next_steps.md`.  
After meaningful work: update `current_state.md`, append `change_log.md`, update `next_steps.md`, `decisions.md` if needed.

---

## Suggested first prompt for Claude / ChatGPT

> You are helping finish Relaxed Living Valet (Flutter + Supabase). Read the handoff above. Current goal: [RUN MIGRATION 032 / APPLY MIGRATIONS 012-014 / DEMO PROPERTY SETUP / STRIPE PLAN / PRIVACY POLICY DRAFT]. Follow existing patterns; do not invent new roles or billing rules. Prefer minimal targeted changes. Update brain files when done.

**If the owner just wants to know what's left**, use this one instead:**

> Read `brain/next_steps.md` (the START HERE box at the top), `brain/current_state.md`, and `HANDOFF_FOR_REGGIE.md`. Tell me in plain English what I still have to do myself, in order, and where my sales files are. Don't write any code.

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
