# Project Handoff — Relaxed Living Valet

**Last updated:** May 27, 2026  
**Purpose:** Single document summarizing AI-assisted development sessions, current product state, and what to do next.  
**Repo:** https://github.com/relaxedlivingvalet/valettrashmobile (`main`)

---

## 1. Executive summary

**Relaxed Living Valet** is a Flutter + Supabase app for apartment valet trash service. Six role-based dashboards (resident, worker, operations manager, property manager, owner, admin portal) share one codebase.

| Readiness | Status |
|-----------|--------|
| Sales demo (web) | **Ready** |
| Limited pilot (1–2 properties) | **~2–4 weeks** after security migrations |
| App Store / Play Store (hardened) | **~4–8 weeks** |

**Biggest blockers before real launch:** apply Supabase migrations **012–014** (RLS hardening), production auth URLs, legal pages (Privacy/Terms), Stripe webhooks if charging.

---

## 2. Infrastructure

| Item | Value |
|------|-------|
| **GitHub** | `relaxedlivingvalet/valettrashmobile` |
| **Supabase project** | `relaxedl-living` |
| **Project ref** | `airpwzzkyjqzeeqizvft` |
| **Region** | AWS us-east-2 |
| **Local dev URL** | http://localhost:8091 |
| **App entry** | `mobile/lib/main.dart` → `ValetApp` |
| **Env file** | `mobile/.env` (gitignored; template: `mobile/.env.example`) |
| **Bundle ID** | `com.relaxedliving.valet` |
| **Deep link (auth)** | `com.relaxedliving.valet://login-callback` |

### Run locally
```powershell
cd mobile
flutter pub get
flutter run -d web-server --web-port 8091 --no-pub
```

### Release builds (not debug)
```powershell
flutter build web --release
flutter build appbundle --release   # Android
flutter build ipa --release         # iOS — requires Mac + Apple Developer
```

---

## 3. Login & test accounts

Full list: **`brain/test_credentials.md`**

| Who | Email | Password | Sign-in mode |
|-----|-------|----------|--------------|
| **Business owner** | `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | **Staff** |
| Operations manager | `adam.grant824+om@gmail.com` | `TestPass123!` | Staff |
| Property manager | `adam.grant824+pm@gmail.com` | `TestPass123!` | Staff |
| Worker / driver | `adam.grant824+worker@gmail.com` | `TestPass123!` | Staff |
| Resident (unit 104) | `adam.grant824+res2@gmail.com` | `TestPass123!` | **Resident** |

**Owner vs Admin:** Same login. Lands on **Owner dashboard** (Financials, labor, portfolio). **Admin Portal** (users, properties, invite codes, billing tools) via top bar or **More → Admin Portal**. Switch back via **Owner Dashboard** bar on admin.

**Test property:** Sunset Gardens · Unit **104** · Invite code **`WELCOME104`**

---

## 4. Roles & navigation

| DB role | Screen | Theme |
|---------|--------|-------|
| `resident` | `ResidentDashboardScreen` | Dark |
| `driver` | `WorkerDashboardScreen` | Dark |
| `operations_manager` | `ManagerDashboardScreen` | Dark |
| `property_manager` | `PropertyManagerDashboardNewScreen` | Light |
| `owner` / `super_admin` | `OwnerDashboardScreen` | Light |
| Admin Portal | `AdminDashboardScreen` (from Owner) | Light |

**Auth flow:** `AuthGate` → session check → `RoleHome` polls `fetchUserRole()` → routes by `users.role`.

**Staff signup:** Staff invite code → `register_staff_with_invite` RPC (not resident flow).

**Resident signup:** Property + unit + invite code → `verify_invite_code` / `claim_invite_code` RPCs.

---

## 5. What was built (chat session history)

### Session themes (chronological summary)

| Period | Work completed |
|--------|----------------|
| **Foundation** | Supabase schema, 6 dashboards wired to live data, auth, role routing, dark/light themes |
| **Resident UX** | Comeback tiers (1 free/month, banked packs), service requests, concerns, IndexedStack tab fix |
| **Admin portal** | Users, properties, residents, concerns, tools (invites, assignments, billing) |
| **Staff invites** | Self-signup for PM/OM/driver; fixed race where staff landed on resident UI |
| **PM dashboard** | Occupancy/vacant units, 85% billable banner, export unit codes CSV, pickup SLA |
| **Owner financials** | Per-property revenue/door, MRR, contractor payouts list, CSV export |
| **Billing (85% rule)** | `PropertyBilling` helper; admin Property Billing Rates; door count fields (011) |
| **Workforce / labor** | Worker clock in/out; OM Workforce & Timecards; owner labor $ from hours × rate |
| **Owner login unify** | `owner` ≡ `super_admin` → one Owner dashboard; Admin via More |
| **Owner ↔ Admin switch** | Top quick-switch bars both directions (same session, no re-login) |
| **Go-live kickoff** | `go_live_checklist.md`, migration 014 RLS hardening, smoke test SQL |

### Notable bugs fixed

| Bug | Fix |
|-----|-----|
| Staff signup showed resident dashboard | `RoleHome` polls `fetchUserRole()` instead of defaulting to resident |
| Admin invite codes insert failed | Column `use_count` not `current_uses` |
| PM compile error on billing | `minPct` int vs double for `minimumBillableDoors` |
| Owner had no dedicated login path | Unified owner/super_admin routing + docs |

---

## 6. Feature map by role

### Resident
- Home: next service, worker ON DUTY badge (from `clock_events`), comebacks, ratings
- Services / extra service requests (date + time)
- Support / concerns
- Signup: **Resident** button + invite code

### Worker (driver)
- Route tab: clock in/out, share location, mark stops, violations with photos
- Earnings: hours from `clock_events`
- Messages (direct_messages)

### Operations manager
- Overview: on-time %, service completion chart, tonight's runs
- **Workforce & Timecards:** on-duty, week hours, shift history
- **Live Worker Map:** GPS from `worker_locations`
- Alerts / notifications to residents

### Property manager
- Dashboard: pickup SLA, satisfaction, pending comebacks
- **Properties:** occupied/vacant, invite codes, 85% billable estimate, **Export CSV**
- Inbox: pending comebacks
- Compliance reports

### Owner
- **Financials:** contract revenue, labor est (clock × rate), revenue/door, MRR, payouts, Export CSV
- **Manage rates:** driver hourly pay (`OwnerWorkforceScreen`)
- Reports: occupancy + billable per property
- More: Admin Portal, service requests inbox, preview other role dashboards

### Admin Portal (Owner → Admin)
- Users, Properties, Residents, Concerns/Service requests
- Tools: Resident Invite Codes, Staff Invite Codes, Property Billing Rates, Manager/Worker Assignments, Add Property

---

## 7. Business rules (must preserve)

### Billing (property managers pay you)
- **Billable doors** = `max(occupied_doors, ceil(total_doors × 85%))`
- Default **$25/door/month** (`monthly_fee_per_door` on `properties`)
- Set total/occupied doors + rate in **Admin → Property Billing Rates**
- Helper: `mobile/lib/core/billing/property_billing.dart`

### Resident comebacks
- **1 free per calendar month** (no rollover)
- **Purchased credits** roll over (`resident_units.purchased_comeback_balance`)
- Paid packs: 1/$5, 3/$14, 5/$20 (Stripe checkout still placeholder)

### Worker status (resident home)
- **ON DUTY** when latest `clock_events` for property is `clock_in`
- Not based on `nightly_runs.status`

### Resident invite workflow
- Super admin generates codes → stored in Supabase → PM sees on Properties tab
- PM exports CSV; **no auto-email** to PM or residents
- Playbook: **`brain/resident_invite_workflow.md`**

### Workforce / payroll
- **OM:** operational view (timecards, map, on-duty)
- **Owner:** financial view (hours × hourly rate, edit rates)
- Default driver rate: **$18/hr** in DB; editable via Owner → Manage rates
- Steps/pedometer: **not built** (deferred)

---

## 8. Database migrations

### Applied on hosted Supabase (through 011)
| Migration | Purpose |
|-----------|---------|
| 007 | `service_requests`, `owner` role |
| 008 | Comeback balance, service preferred_time |
| 009 | Staff invites + RPCs |
| 010 | Billing metrics ($/door, 85% min %) |
| 011 | Manual door counts on properties |

### In repo — **apply manually** (blocker)
Run in [Supabase SQL Editor](https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft/sql/new) **in order**:

1. `supabase/migrations/012_workforce_labor.sql`
2. `supabase/migrations/013_unify_owner_role.sql`
3. `supabase/migrations/014_launch_rls_hardening.sql`

Then run: `supabase/tests/rls_role_smoke.sql` (expect **zero** tables without RLS).

---

## 9. Key files (quick reference)

| Path | Purpose |
|------|---------|
| `mobile/lib/valet_app.dart` | AuthGate, RoleHome routing |
| `mobile/lib/core/auth/user_profile.dart` | Role polling after signup |
| `mobile/lib/core/billing/property_billing.dart` | 85% billable math |
| `mobile/lib/core/workforce/clock_hours.dart` | Shift hours + labor cost |
| `mobile/lib/features/owner/screens/owner_dashboard_screen.dart` | Owner UI |
| `mobile/lib/features/admin/screens/admin_dashboard_screen.dart` | Admin portal |
| `mobile/lib/features/manager/screens/om_workforce_screen.dart` | OM timecards |
| `mobile/lib/features/owner/screens/owner_workforce_screen.dart` | Owner labor $ |
| `mobile/lib/features/owner/widgets/owner_admin_switch_bar.dart` | Owner ↔ Admin switch |
| `supabase/migrations/` | All SQL migrations |
| `brain/` | Project memory (read first each session) |

---

## 10. Known gaps & constraints

| Area | Status |
|------|--------|
| **RLS on hosted DB** | Many tables had RLS off; fix in migration 014 — **not confirmed applied** |
| **Stripe Connect** | UI reads `contractor_payouts`; webhooks not live |
| **Paid comebacks / pickup packs** | DB state updates; Stripe checkout placeholder |
| **Push notifications** | Not wired (Phase 2) |
| **Worker GPS on native** | Web uses `dart:html`; needs `geolocator` for iOS/Android |
| **CSV export on native** | Web `dart:html`; needs `share_plus` |
| **Bulk unit import** | Backlog |
| **Privacy Policy / Terms in app** | Not linked in UI yet — required for stores |
| **Production Supabase** | Still localhost URLs; need staging + prod projects |
| **Test passwords in docs** | Rotate before public launch |

---

## 11. Go-live order (do in sequence)

Full detail: **`brain/go_live_checklist.md`**

### Legal & business (before real residents)
1. LLC/corp, insurance, property contracts, worker agreements
2. Privacy Policy + Terms of Service (published URLs)
3. Support contact page

### Technical security
4. Apply migrations 012 → 013 → 014
5. RLS smoke test + Supabase Database Linter clean
6. Separate **staging** and **production** Supabase projects
7. Production auth URLs + email provider (Resend/SendGrid)
8. Remove test accounts from production

### QA (after RLS)
9. Full role test pass (owner, admin switch, resident signup, worker clock, PM scope)
10. One-property pilot (5–10 real residents)

### Stores & release
11. Release builds (`appbundle` / `ipa`)
12. Play Internal + TestFlight
13. Privacy labels + store listings
14. Native GPS + CSV fixes before broad mobile rollout

---

## 12. Git history (recent `main`)

| Commit | Summary |
|--------|---------|
| `87b3477` | Brain hash for go-live commit |
| `2f0c9b8` | Go-live checklist + migration 014 |
| `8b5b8aa` | Owner ↔ Admin two-way switch |
| `eb29777` | Unify owner + super_admin login |
| `401b13e` | OM timecards + owner labor estimates |
| `48ec1cf` | Billing door counts UI (011) |
| `b41ae6a` | Owner financials + PM billing + invite playbook |
| `2a996f7` | Staff invite self-signup |

---

## 13. Brain folder index

| File | Use when |
|------|----------|
| **`project_handoff.md`** | **This file — start here for full context** |
| `current_state.md` | Latest objective + resume steps |
| `next_steps.md` | Active checklist |
| `go_live_checklist.md` | Launch phases 0–4 |
| `test_credentials.md` | Logins |
| `resident_invite_workflow.md` | Onboarding a property |
| `decisions.md` | Why things were built this way |
| `change_log.md` | Session-by-session code changes |
| `architecture.md` | Modules + data flow |
| `project_context.md` | Stack + goals |

---

## 14. Cursor / AI development notes

- **Brain files** (`brain/`) must be read/updated each meaningful session (repo rule).
- **Auto-run:** Cursor Settings → Agents → Run Mode → Auto-Run in Sandbox (fewer approval prompts).
- **MCP Supabase** timed out when applying migration 014 — apply SQL manually in dashboard.
- **Do not commit** `mobile/.env` or `service_role` keys.
- **Commits:** Only when explicitly requested; pushes to `main` documented in `change_log.md`.

---

## 15. Immediate next actions (copy-paste checklist)

- [ ] Apply `012_workforce_labor.sql` on Supabase
- [ ] Apply `013_unify_owner_role.sql` on Supabase
- [ ] Apply `014_launch_rls_hardening.sql` on Supabase
- [ ] Run `supabase/tests/rls_role_smoke.sql`
- [ ] QA all roles at http://localhost:8091
- [ ] Draft Privacy Policy + Terms (lawyer review)
- [ ] Create production Supabase project
- [ ] Pilot one property per `resident_invite_workflow.md`

---

*For questions or continuing development, open `brain/current_state.md` and `brain/next_steps.md` first, then this handoff.*
