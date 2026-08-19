# Current State

## Current Objective
**Go-live readiness** — legal foundation + security sprint (RLS) → pilot → store release. Repo migrations through **014**. Master plan: **`brain/go_live_checklist.md`**.

## Resume Here (next session)
**Ordered playbook (do in sequence):**

1. **Legal / business** — LLC done; marketing site **https://relaxlivingvalet.com** live; still need Privacy/Terms pages on that site, bank (Stripe live), insurance, property/worker agreements.
2. **Apply migrations `012` → `013` → `014`** on hosted Supabase (Advisor shows RLS off on core tables until 014). Then run `supabase/tests/rls_role_smoke.sql`.
3. **Stripe secrets** — owner must paste `STRIPE_SECRET_KEY` + webhook `whsec_` into Edge Function secrets (`brain/stripe_setup.md`). Existing Stripe account is **not** auto-linked.
4. **In-person iPad demo (no Mac yet):** same Wi-Fi as PC → Safari `http://<PC-LAN-IP>:8091`. `localhost:8091` only works on the PC. Marketing site is **not** the Flutter app.
5. **Installable iPad app:** Apple Developer ($99) + **Mac + Xcode** → TestFlight (do this before public App Store). Windows cannot build iOS.
6. Role QA after RLS; then staging/prod + store listings.

**External AI handoff:** `brain/handoff_for_external_ai.md`.

Blockers: hosted 012–014 not applied (Advisor: ~24 RLS-off issues); Stripe secrets/webhook still owner action; no Mac for TestFlight; Privacy/Terms not published yet; business bank for Stripe live.

## Run the App
```powershell
cd C:\Users\WeLovePQ\Desktop\CascadeProjects\windsurf-project\mobile
flutter pub get
flutter run -d web-server --web-port 8091 --no-pub
```

App: **http://localhost:8091** (this PC only). iPad on same Wi-Fi: `http://<this-PC-IPv4>:8091`. Marketing: **https://relaxlivingvalet.com**.

---

## Supabase

| Item | Value |
|---|---|
| Project | `relaxedl-living` |
| Ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| MCP | `project_ref=airpwzzkyjqzeeqizvft` |

### Live migrations (hosted)
| Hosted name | Repo file | What it does |
|---|---|---|
| `007_service_requests` | `007_service_requests.sql` | `service_requests` + owner role |
| `resident_comeback_balance_service_time` | `008_...sql` | `purchased_comeback_balance`, `preferred_time` |
| `staff_invites` | `009_staff_invites.sql` | Staff self-signup RPCs |
| `property_billing_metrics` | `010_property_billing_metrics.sql` | `monthly_fee_per_door` (default $25), `minimum_billable_occupancy_percent` (default 0.85) |
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
