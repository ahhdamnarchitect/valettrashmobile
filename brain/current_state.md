# Current State

## Current Objective
**Backend is done and audited (2026-08-19).** Live on the dedicated Supabase project
`immiejqvnucndjspacwv`: 33 tables, RLS on **all** of them, 122 policies, **0 Security Advisor
errors**, both Edge Functions deployed, all 7 demo accounts verified logging in with each role
correctly scoped. Repo migrations through **032**.

Ten migrations (`016`–`025`) fixed four latent defects that had been in the repo since the
beginning plus six security/access findings — including a **confirmed data leak** (`audit_logs`
was readable by any authenticated user) and a **Stripe webhook bug** that would have charged
customers without delivering credits. Details: `supabase/MIGRATIONS.md`.

Remaining before launch is owner action only: Stripe secrets, webhook endpoint, GitHub
integration re-link, custom SMTP. See `brain/next_steps.md`. Master plan:
**`brain/go_live_checklist.md`**.

## Resume Here (next session)
**Ordered playbook (do in sequence):**

1. **Legal / business** — LLC done; marketing site **https://relaxedlivingvalet.com** live; still need Privacy/Terms pages on that site, bank (Stripe live), insurance, property/worker agreements.
2. **Apply migrations `012` → `013` → `014`** on hosted Supabase (Advisor shows RLS off on core tables until 014). Then run `supabase/tests/rls_role_smoke.sql`.
3. **Stripe secrets** — owner must paste `STRIPE_SECRET_KEY` + webhook `whsec_` into Edge Function secrets (`brain/stripe_setup.md`). Existing Stripe account is **not** auto-linked.
4. **In-person iPad demo (no Mac yet):** same Wi-Fi as PC → Safari `http://<PC-LAN-IP>:8091`. `localhost:8091` only works on the PC. Marketing site is **not** the Flutter app.
5. **Installable iPad app:** Apple Developer ($99) + **Mac + Xcode** → TestFlight (do this before public App Store). Windows cannot build iOS.
6. Role QA after RLS; then staging/prod + store listings.

**External AI handoff:** `brain/handoff_for_external_ai.md`.

Blockers: hosted 012–014 not applied (Advisor: ~24 RLS-off issues); Stripe secrets/webhook still owner action; no Mac for TestFlight; Privacy/Terms not published yet; business bank for Stripe live.

### 💰 Pricing model — ANSWERED 2026-08-21, code corrected, **migration not yet applied**

Reggie confirmed the model: **the property pays Relaxed Living Valet, and the property bills its
residents.** His rate is **$15–18/door/month**; residents are charged **$25–35** by the property,
which keeps the spread. Full offer terms: **`brain/sales/offer.md`**.

> ✅ **Fixed in the repo 2026-08-21 — but NOT yet applied to the live database.** The default was
> `25.00`, which conflated the resident-facing fee with the rate the property pays us and would
> have quoted every new property ~$7–10/door too high. Corrected to **`18.00`** (the
> month-to-month rate; 15.00 on a 36-month term is set per property) in **three** places:
> migration **`20260516000032_correct_monthly_fee_per_door_default.sql`**,
> `supabase/provision/part3_features_and_rls.sql` (fresh-provision path), and
> `PropertyBilling.defaultMonthlyFeePerDoor` in the Flutter app.
>
> 🔴 **Owner action: migration 032 still has to be run on the hosted project.** Until then the live
> DB still defaults to 25.00. See `brain/next_steps.md`.

Two smaller items the answer surfaced, both unresolved:
- **`minimum_billable_occupancy_percent` (default 0.85)** appears in the app but in **neither
  contract template**. Is he charging it? A property manager will ask.
- The **monthly billing export** (property invoice + per-unit backup file, plus a nullable
  `external_ref` to carry the property's own unit/tenant codes) is now unblocked but **not built**.

**Ruled out 2026-08-21:** Yardi / RealPage / Entrata integrations — we are *ineligible*, not just
priced out (Yardi needs 2 years in business + 3 active Voyager clients before API access exists).
The honest sales answer and the substitute deliverable are in `decisions.md`.

### 📇 Sales assets — BUILT 2026-08-21

`brain/sales/` now exists and is the selling side of this project:

| File | What it is |
|---|---|
| **`offer.md`** | Source of truth — pricing, ICP, service spec, contract structure, compliance kit, open items. **Change a number here first, then propagate.** |
| **`sales-script.md`** | Two spines (leasing-office walk-in + cold call), qualifying questions, objections, competence checks, disqualify |
| **`pitch-practice.md`** | Roleplay prompt — dice-rolled prospect scenarios, COACH/SCORE |
| **`roleplay-project-instructions.txt`** | Condensed paste-in version for ChatGPT voice |
| **`call-card.html`** | "Breezeway Board" — tap-through card for use in a parking lot. Published: https://claude.ai/code/artifact/28c6c84e-9b85-4917-ae6b-0630a31f1596 |

⚠️ The script quotes **$18/door month-to-month, $15/door on 36 months**. Reggie gave a *range*
($15–18); **the split is Adam's recommendation and is not yet confirmed by Reggie** — see the
flagged assumption at the top of `offer.md`.

## Run the App
```powershell
cd C:\Users\WeLovePQ\Desktop\CascadeProjects\windsurf-project\mobile
flutter pub get
flutter run -d web-server --web-port 8091 --no-pub
```

App: **http://localhost:8091** (this PC only). iPad on same Wi-Fi: `http://<this-PC-IPv4>:8091`. Marketing: **https://relaxedlivingvalet.com**.

---

## Supabase

| Item | Value |
|---|---|
| Project | **RLV** (org: Relaxed Living Valet, Free plan) |
| Ref | `immiejqvnucndjspacwv` |
| Branch | `main` (production) |
| Auth | email/password; confirm-email **off** (invite-code gated); min 8 chars + all classes |
| Storage | `violations` bucket, **private**, 5 policies |
| Edge Functions | `create-checkout-session` (JWT on), `stripe-webhook` (JWT **off**) |
| MCP | `project_ref=immiejqvnucndjspacwv` |

### Live migrations (hosted)
| Hosted name | Repo file | What it does |
|---|---|---|
| `007_service_requests` | `007_service_requests.sql` | `service_requests` + owner role |
| `resident_comeback_balance_service_time` | `008_...sql` | `purchased_comeback_balance`, `preferred_time` |
| `staff_invites` | `009_staff_invites.sql` | Staff self-signup RPCs |
| `property_billing_metrics` | `010_property_billing_metrics.sql` | `monthly_fee_per_door` (default now **$18** — see migration 032), `minimum_billable_occupancy_percent` (default 0.85) |
| `property_door_counts` | `011_property_door_counts.sql` | `billing_total_doors`, `billing_occupied_doors` (manual entry per complex) |
| `workforce_labor` | `012_workforce_labor.sql` | `users.hourly_rate`, clock_events/worker_locations RLS, `set_worker_hourly_rate` RPC — **not applied hosted** |
| `unify_owner_role` | `013_unify_owner_role.sql` | `relaxedlivingtx@gmail.com` → `owner`; optional `+owner` alias — **not applied hosted** |
| `launch_rls_hardening` | `014_launch_rls_hardening.sql` | Re-enable RLS, `is_owner_admin()`, satellite table policies — **not applied hosted** |
| `stripe_payments` | `015_stripe_payments.sql` | `payment_orders` + Stripe columns on comebacks (**applied hosted Aug 13**) |

### Billing rules (app + DB)
- **Inputs (owner via Admin Portal):** total doors, occupied doors, $/billable door/month on **Property Billing Rates**.
- **Billable doors** = `max(occupied, ceil(total × 85%))` — app calculates occupancy % and monthly $.
- Falls back to counted units + `resident_units` when door counts not saved yet.
- **PM contract estimate** = billable doors × `monthly_fee_per_door`.
- **Owner revenue/door** = (contract + resident MRR + paid invoices + paid comebacks) ÷ billable doors per property.
- **Stripe Checkout** — packs 1/$5, 3/$14, 5/$20 and paid single comeback; webhook credits after `checkout.session.completed`.
- **Stripe Connect** — contractor payouts UI ready; live Connect onboarding still pending.

---

## Flutter App (`mobile/`)

### Role → Screen
| Role | Screen | Theme |
|---|---|---|
| `resident` | `ResidentDashboardScreen` | Dark |
| `driver` | `WorkerDashboardScreen` | Dark |
| `operations_manager` | `ManagerDashboardScreen` — **Workforce & Timecards**, Live Worker Map | Dark |
| `property_manager` | `PropertyManagerDashboardNewScreen` | Light |
| `owner` / `super_admin` | `OwnerDashboardScreen` — Admin Portal quick switch (top bar + More) | Light |

### Auth / routing
- Login: **Resident** | **Staff** buttons.
- **`owner` ≡ `super_admin`** — both → `OwnerDashboardScreen`; **Admin Portal** from More and top quick switch bar.
- **Owner test login:** `relaxedlivingtx@gmail.com` / `RelaxedLiving2026!` (Staff).
- `RoleHome` polls `fetchUserRole()` after signup (fixes PM landing as resident race).
- Staff: `staff_invites` + `register_staff_with_invite`.

### Who uses which dashboard
- **`property_manager`** = apartment office / complex manager (pickup %, occupancy, announcements) — **not** Relaxed Living’s owner.
- **`owner`** = Relaxed Living (you) — Financials, all properties, Admin Portal.
- Apartment-building landlords who want that overview use a PM login (no separate “complex owner” role).

### Property manager dashboard
| Tab | Content |
|---|---|
| Dashboard | Pickup SLA, satisfaction, pending comebacks (no resident service requests) |
| Properties | Units list: **Occupied/Vacant**, invite codes, **85% billable** banner, est. monthly bill, **Export CSV** |
| Inbox | Pending comebacks only |
| More | Compliance reports, password, sign out |

### Owner dashboard
| Tab | Content |
|---|---|
| Overview | Portfolio summary |
| **Financials** | Contract revenue, **labor est from clock**, revenue/door, MRR, payouts, **Manage rates** → `OwnerWorkforceScreen`, **Export CSV** |
| Reports | Properties with occupancy + billable + $/door |
| More | **Admin Portal**, service requests inbox, role switchers (preview other dashboards) |

### Admin portal
| Area | Content |
|---|---|
| Top quick switch | **Owner Dashboard** button (returns without re-login) |
| Tools | Invite codes, billing rates, assignments, and **Owner Dashboard** switch tile |

### Owner onboarding (Admin Portal via More)
| Task | Where |
|---|---|
| Add property | Admin → Properties → Add |
| Units + resident codes | Admin → Tools → **Resident Invite Codes** (`brain/resident_invite_workflow.md`) |
| Staff codes | Admin → Tools → **Staff Invite Codes** |
| Link PM/OM/driver | Admin → Manager / Worker Assignments |
| **Door counts + $/door** | Admin → Tools → **Property Billing Rates** |
| **Driver pay rates** | Owner → Financials → **Manage rates** (or `OwnerWorkforceScreen`) |

### Workforce / labor
- **Worker** — Clock in/out → `clock_events`; Route → Share Location → `worker_locations`; More → Earnings (hours).
- **OM** — `OmWorkforceScreen`: on-duty, week hours, shift history, link to map.
- **Owner** — Financials labor tiles; `OwnerWorkforceScreen`: edit hourly rate via RPC, est week/month labor $.
- **Helper** — `mobile/lib/core/workforce/clock_hours.dart`.

### Go-live artifacts
- **`brain/handoff_for_external_ai.md`** — copy-paste handoff for Claude / ChatGPT / other AI
- **`brain/go_live_checklist.md`** — phased launch plan (demo → pilot → stores)
- **`supabase/migrations/014_launch_rls_hardening.sql`** — RLS hardening
- **`supabase/tests/rls_role_smoke.sql`** — post-migration verification

### Key new files
- `mobile/lib/core/billing/property_billing.dart`
- `mobile/lib/core/workforce/clock_hours.dart`
- `mobile/lib/core/auth/user_profile.dart`
- `brain/resident_invite_workflow.md`
- `brain/test_credentials.md`
- `supabase/seed_data/013_owner_test_account.md`

### Recent GitHub (`main`)
| Commit | Summary |
|---|---|
| `7c5d417` | Stripe Checkout for packs + paid comebacks |
| `834a7b3` | External AI handoff doc |
| `c5af2db` | Owner/Admin two-way quick switch |

---

## Retest Checklist

**Owner**
- [ ] Staff login → Owner dashboard (not resident)
- [ ] More → Admin Portal opens
- [ ] Admin top bar → Owner Dashboard returns to owner
- [ ] Financials: labor est + Manage rates
- [ ] Export financials CSV downloads

**PM**
- [ ] Properties shows occupied vs vacant per unit
- [ ] Billable count reflects 85% minimum when occupancy is low
- [ ] Export unit codes CSV

**Staff signup**
- [ ] Staff code → property manager dashboard (not resident)

**Accounts:** `brain/test_credentials.md` — owner `relaxedlivingtx@gmail.com` · OM/worker/PM `adam.grant824+*` · resident `+res2`

---

## Known Issues / Constraints
- **Stripe** — Checkout + webhook **code deployed**; secrets not in Supabase yet (existing Stripe login is not auto-connected). Connect payouts still pending.
- **RLS** — hosted Advisor: policies exist but RLS **disabled** on core tables (`users`, `properties`, `resident_units`, pickups, invoices, …) until 014 applied. Newer tables (`payment_orders`, `staff_invites`, `clock_events`) already have RLS on.
- **iPad / App Store** — Flutter web on this Windows PC only; iOS IPA needs Mac + Apple Developer; TestFlight is the in-person install path (not public App Store first).
- **Web-only CSV / worker GPS** — `dart:html`; native needs `share_plus` / `geolocator` before store.
- Live DB may have **0** subscriptions/invoices until seed or Stripe — contract math still works from units + fee
