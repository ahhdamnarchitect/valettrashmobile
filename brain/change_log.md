# Change Log

## Format
Date | Change | Files Modified | Reason

---

### 2026-08-21 — Sales assets built (`brain/sales/`); pricing model answered

- **Pricing model resolved.** Reggie confirmed: **the property pays RLV, the property bills its
  residents.** His rate is **$15–18/door/month**; residents pay **$25–35**, property keeps the
  spread. This unblocked the sales-asset build and the billing export.
  🔴 **The app still defaults `monthly_fee_per_door` to `25.00`** — now known to be wrong by $7–10
  a door. Needs a migration. **Files:** `brain/sales/offer.md`, `brain/current_state.md`.

- **Built `brain/sales/`** — the selling side of the project, ported from the proven
  `journeyman/ops/outreach/` assets (formerly `home-services-growth`):
  - **`offer.md`** — source of truth: pricing, ICP, service spec, contract structure, compliance
    kit, open items. All other sales files derive from it.
  - **`sales-script.md`** — two spines (leasing-office walk-in + cold call), the two qualifying
    questions, discovery branched by prospect state, objection cheat sheet, operational competence
    checks, honest disqualify, NEVER SAY.
  - **`pitch-practice.md`** + **`roleplay-project-instructions.txt`** — ChatGPT-voice roleplay
    partner with dice-rolled prospect scenarios (four personas incl. a leasing agent who *cannot
    buy* and a preferred-vendor disqualify), plus COACH/SCORE.
  - **`call-card.html`** — "Breezeway Board", the tap-through card. Verified in both themes and at
    mobile width. Published: https://claude.ai/code/artifact/28c6c84e-9b85-4917-ae6b-0630a31f1596

- **Read both contract templates** (month-to-month and 36-month) and encoded their real terms into
  the offer and script. Key finding: **the month-to-month — 30-day out, either party, no
  liquidated damages — is the strongest asset in the whole offer**, because no national competitor
  will match it and it directly answers "you're new, why would I risk my property on you."

- **Discrepancies caught between what Reggie said and what the contracts say.** Reggie confirmed
  resolutions for all four: **cans are $40, not $20** (contracts win); **Juneteenth** and an
  **inclement-weather clause** are being added to the contracts (currently in neither); and
  **additional-insured** language is being added (§12/§13 currently promise only a COI on request,
  which most management companies will not accept).

- **Still open** — tracked in `brain/sales/offer.md`: the $18/$15 split is *Adam's recommendation,
  not Reggie's confirmed number*; contract **Schedules 1–4 do not exist** (services, rates,
  acceptable and excluded waste — he cannot hand over a complete contract yet); the 36-month
  template references the rate schedule as **Schedule 4 in §8 and Schedule 1 in §10**; and Reggie's
  **real 30-day capacity ceiling** is unknown ("as many as possible" is not a number the script
  will repeat).

### 2026-08-21 — Marketing domain typo corrected; PM-software integration ruled out

- **Fixed a wrong marketing domain in 16 places across 8 files.** Every doc said
  **`relaxlivingvalet.com`** — that domain does not resolve (NXDOMAIN). The live site is
  **`relaxedlivingvalet.com`** (Vercel, DFW valet trash, phone 817-239-0269).
  This was not cosmetic: `HANDOFF_FOR_REGGIE.md` Step 3 instructed Reggie to add
  `relaxlivingvalet.com` to Resend and set the SMTP sender to `noreply@relaxlivingvalet.com` —
  he would have been verifying a domain he does not own, and **password-reset email would never
  have worked**. **Files:** `HANDOFF_FOR_REGGIE.md`, `brain/project_context.md`,
  `brain/current_state.md`, `brain/test_credentials.md`, `brain/go_live_checklist.md`,
  `brain/handoff_for_external_ai.md`, `brain/decisions.md`, `brain/change_log.md`.

- **Yardi / RealPage / Entrata integration ruled out — ineligible, not merely expensive.** Yardi's
  Standard Interface Partner Program gates all API access behind **2 years in business + 3 active
  Voyager clients**, then ~**$25K/interface/year**; RealPage certifies every AppPartner and
  Registered Vendor; Entrata is partner-gated. Full reasoning and the honest sales answer:
  `brain/decisions.md` (2026-08-21). The substitute deliverable — a monthly property invoice plus a
  per-unit backup file, and a nullable `external_ref` to carry the property's own unit/tenant codes —
  is **on hold** pending the pricing-model question below. **Files:** `brain/decisions.md`.

- **Pricing model flagged as a blocking open question.** Market rate is **$8–15/door/month paid by
  the property**, with **residents charged $25–35**; the property's whole business case is that
  spread. Our schema defaults `monthly_fee_per_door` to **$25.00** and `current_state.md` defines the
  PM contract as billable doors × that fee — i.e. 2–3× market billed to the property, with their
  profit erased. Awaiting Reggie's answer. **Files:** `brain/decisions.md`.

- **Context:** this session was research toward porting the `home-services-growth` sales assets
  (call script, ChatGPT-voice roleplay prompt, and the clickable "Dispatch Board" call card) to
  Relaxed Living Valet. Those assets are **not built yet** — they are blocked on the pricing answer.


### 2026-08-19 — Pulled 25 commits; repo hygiene; switched to dedicated Supabase project

- **Pulled `origin/main`** (fast-forward, `f46aaef` → `33c268b`, 25 commits). Resolves the fork-sync
  risk flagged on 2026-08-11 — the remote *had* moved on (Stripe checkout, owner/admin unification,
  RLS hardening, migrations 009–015, marketing site).
- **Discarded ~79 files of CRLF working-tree noise** (verified line-ending-only, no content), and added
  **`.gitattributes`** (`* text=auto eol=lf` + binary rules) so it cannot recur. Closes the
  normalization item in `next_steps.md`. **Files:** `.gitattributes`.
- **Untracked `mobile/.env`** (`git rm --cached`; file kept on disk). `mobile/.gitignore` already had
  `.env`, but the tracked copy overrode it. ⚠️ The old anon key remains in git history — moot now that
  the project changed, but note it if the old project is ever reused.
- **Switched Supabase to the dedicated project `immiejqvnucndjspacwv`** (was `airpwzzkyjqzeeqizvft`).
  Both apps read config from env, so no Dart/TS changes were needed. **Files:** `mobile/.env.example`,
  `mobile/README.md`, `supabase/MIGRATIONS.md`, `brain/current_state.md`, `brain/stripe_setup.md`,
  `brain/handoff_for_external_ai.md`, `brain/test_credentials.md`. Old ref deliberately left in
  `brain/change_log.md` and `docs/superpowers/plans/` (historical record) and `.cursor/mcp.json` (retired).
- **Resolved the long-open 4-vs-6 role-enum conflict.** `007_service_requests.sql` adds `owner` and
  `009_staff_invites.sql` adds `operations_manager` via `ALTER TYPE ... ADD VALUE IF NOT EXISTS`. The
  repo migrations *do* now cover all six roles; the 2026-08-09 concern is closed.
- **Found two provisioning traps and built `supabase/provision/`** (4 ordered bundles) around them:
  1. `007`/`009` add an enum value then use it in the same script → Postgres `unsafe use of new value`.
     Split the two `ALTER TYPE` statements into `part2`, which must commit before `part3`.
  2. `seed_data/001_seed_users.sql` inserts hardcoded UUIDs but `public.users.id` is FK to
     `auth.users(id)` → every insert fails on a fresh project; seeds `004`–`009` inherit the problem.
     `part4` keys profile rows to real auth UUIDs by email lookup instead.
- **Rewrote `supabase/MIGRATIONS.md`** — it stopped at `008`, omitted both traps, and told you to run
  seeds in numeric order (which fails). Now documents `009`–`015`, the provision bundles, and a
  per-seed safety table. Also confirmed `002_indexes.sql` / `003_triggers_functions.sql` are exact
  duplicates of the `001` baseline and that `002_indexes.sql` lacks `IF NOT EXISTS` guards.
### 2026-08-19b — Security audit + backend completion (ship-ready)

- **Created the 7 demo auth users** via SQL (`provision/part4a_auth_users.sql`) with bcrypt
  password hashes + `auth.identities` rows, then ran part4/part5. **Verified every role can
  actually log in** through `/auth/v1/token`. 7 auth users = 7 profile rows, correct roles.
- **Wired the demo**: PM -> Sunset Gardens via `user_properties`, worker via
  `worker_assignments`, resident to unit 104 via `resident_units`.
- **Found and fixed a confirmed-exploitable data leak.** `audit_logs` had
  `USING (auth.uid() IS NOT NULL)` - ANY authenticated user could read it, and it stores
  `row_to_json()` snapshots of every change to properties, units, resident_units, violations
  and subscriptions. A resident test account read all 67 rows including property billing
  rates. Now owner-tier only (`020`). **This was a real vulnerability, not a lint warning.**
- **Fixed the owner seeing nothing.** `013` made `owner` canonical but 22 admin policies still
  tested `super_admin`, and `014` covered only 3 of 32 tables - so the business owner logged in
  to 0 units, 0 buildings, 0 routes, 0 invoices. Widened to `is_owner_admin()` (`020`).
- **`stop_completions` did not exist.** The worker dashboard reads AND writes it; the read was
  swallowed by `catch (_) {}` so stops never cleared, and the insert threw. Created with RLS (`022`).
- **PM and ops-manager access fixed.** PMs assigned via `user_properties` (what the app does)
  couldn't see their own properties/buildings/floors/units; `operations_manager` had no access
  to anything. (`021`, `022`, `023`)
- **Function hardening (`024`)**: pinned `search_path` on `audit_trigger` (a definer-escalation
  vector) and `handle_updated_at`; revoked anon EXECUTE on the privileged RPCs.
- **Moved all 10 RLS helpers to a non-exposed `private` schema (`025`)**, rebuilding every
  affected policy programmatically from `pg_policies`. First proved by experiment that simply
  revoking EXECUTE is impossible - it yields `permission denied for function can_access_floor`
  because policies are evaluated as the querying role.
- **Supabase Security Advisor: 35 warnings -> 8, and 0 errors.** The 8 remaining are by design
  (invite-code RPCs must be anon/authenticated callable and authorise internally) or Pro-plan
  only (leaked-password protection).
- **Auth config**: Site URL `http://localhost:8091`, added both redirect URLs (password reset
  deep link was impossible before), password policy min 8 + all character classes.
  **Disabled "Confirm email"** - it was ON, which broke signup two ways: `signUp()` returned no
  session so the immediately-following `claim_invite_code` RPC failed, and the built-in mailer
  rate-limited at 2-3/hour. Signup verified working after. Left "Require current password" and
  "Secure password change" OFF deliberately: the app calls `updateUser(password:)` without the
  old password and reuses that screen for recovery, so enabling them would break password reset.
- **Deployed both Edge Functions** through the dashboard editor, with `stripe-webhook` set to
  **JWT verification OFF** (Stripe calls it without a Supabase token; it authenticates via the
  Stripe signature instead). Both verified reachable.
- **Fixed a Stripe bug that would have taken money without delivering.** The webhook used the
  synchronous `stripe.webhooks.constructEvent()`, which throws
  `SubtleCryptoProvider cannot be used in a synchronous context` under Deno - the catch turned
  that into a generic 400 "Bad signature", so **every** webhook would have failed after the
  customer was charged. Now `constructEventAsync` + `createSubtleCryptoProvider()`.
- **App-side audit clean**: no secrets in the bundle, no hardcoded keys, no cleartext HTTP, no
  ATS bypass, permissions all justified, no sensitive data in logs.
- **Verified end state**: 33 tables, RLS on all, 122 policies, 0 Advisor errors, all 5 roles
  scoped correctly, resident attack probes all blocked (role escalation `42501`, writes `42501`,
  privileged RPC `not authorized`), anon sees `[]`.

- **Provisioned the new Supabase project `immiejqvnucndjspacwv` via the dashboard SQL editor.**
  Confirmed empty first (0 tables / 0 enums / 0 auth users), then applied part1 -> part2 -> part3 -> part4.
  **Final state: 32 tables, RLS enabled on all 32 (0 without), 101 policies, 2 properties, 56 units,
  invite code `WELCOME104`.** This closes the ~24 RLS-off Advisor findings the old project carried.
- **Found and fixed FOUR latent defects that had been in the repo since the beginning.** Each one
  aborts a migration or breaks the API, and together they explain why RLS was never actually live:
  1. `004` — `Users can update own profile` used `OLD.role`. `OLD` is trigger-only syntax and is
     invalid in an RLS policy (`42P01`), which aborted the entire RLS migration. Now a `WITH CHECK`
     against a new `public.current_user_role()` helper.
  2. `001` — `audit_trigger()` read `NEW.created_by`; PL/pgSQL resolves every `NEW.<field>` at
     runtime and **no** audited table has that column (`42703`). Once fixed, `audit_logs.user_id`
     was `NOT NULL` while system actions have no actor (`23502`). Between them, **every INSERT into
     properties, buildings, units, resident_units, worker_assignments, violations and subscriptions
     failed.** Fixed via `to_jsonb(NEW)` lookups + nullable `user_id` (`016`).
  3. `004` — `42P17: infinite recursion`. A policy on `users` selected `FROM users`; separately
     `properties` <-> `resident_units` and `properties` <-> `worker_assignments` formed two mutual
     cycles. Core tables returned HTTP 500. Fixed with `SECURITY DEFINER` helpers (`017`, `018`).
  4. `004` — the PM violations policy JOINs `units->floors->buildings->properties`, each with its own
     multi-branch RLS, and timed out (`57014`) on an **empty** table. Collapsed into
     `public.pm_owns_unit()` (`019`).
  Access semantics are unchanged in all four; `014` already used this `SECURITY DEFINER` shape for
  `is_owner_admin()`. Wrote a cycle-detector over the policy graph to confirm only two cycles existed.
- **Verified end-to-end against the live REST API** with the real publishable key: **28/28 tables
  return 200**, while anon reads return `[]` against seeded rows and anon writes are rejected with
  `42501` — RLS is genuinely enforcing, not merely enabled.
- **Retrieved the publishable key and finished the client switch.** New projects issue
  `sb_publishable_...` rather than a legacy anon JWT; confirmed the server accepts it (auth health
  200). Written to gitignored `mobile/dart_define.json`; `flutter build web` succeeds with the URL
  and key compiled into `main.dart.js` and no `.env` in the bundle.
- **Not done (cannot be):** creating the auth users. That means entering passwords, which I don't do.
  `public.users` and `auth.users` are both still empty — see `brain/next_steps.md`.
- **Cursor tooling stays — reversed an earlier deletion.** `.cursor/rules/`, `.cursor/mcp.json`, and
  `cursor-os/` had been staged for deletion under the "Cursor is retired" rule in `~/Projects/CLAUDE.md`.
  **The client actively uses Cursor on this project**, so these are live shared tooling, not stragglers.
  Restored all 11 files + the README "Cursor Repo OS" section, repointed `.cursor/mcp.json` at
  `immiejqvnucndjspacwv`, and amended this repo's `CLAUDE.md` so future sessions don't re-delete them.
- **Moved client config off a bundled `.env` to compile-time `--dart-define-from-file`.**
  `mobile/pubspec.yaml` listed `.env` as a Flutter **asset**, so it shipped verbatim in every build
  (fetchable at `/assets/.env` on web). Now: `lib/core/config/app_config.dart` exposes
  `String.fromEnvironment` values with an `assertConfigured()` guard that throws a readable error
  naming missing keys; both entry points use it; `.env` dropped from assets; `flutter_dotenv`
  dependency removed (no longer referenced anywhere in `lib/`). Config lives in gitignored
  `mobile/dart_define.json`, template committed as `mobile/dart_define.example.json`.
  **Verified:** `flutter analyze` → 0 errors, 3 pre-existing warnings, none in changed files;
  `flutter build web --dart-define-from-file=dart_define.json` succeeds; the new project URL is
  compiled into `main.dart.js`; `.env` is absent from `AssetManifest.json`.
- **⚠️ Found a stale `build/web/assets/.env` dated May 16** containing the *old* project's URL and
  anon key. `flutter build` does not clear its output dir, so deploying an uncleaned `build/web/`
  would have published it. `flutter clean` removes it — now documented in `mobile/README.md`.
  `mobile/build/` is gitignored and was never committed, so this was a deploy hazard only, not a
  repo leak.
- **Clarified the credential model** (no code impact, recorded so it stops being re-litigated): the
  Supabase anon/publishable key is **not** a secret — it ships in the client by design and RLS is
  the actual boundary. `service_role` and Stripe secrets stay in Supabase Edge Function secrets,
  which is already how both Edge Functions read them (`Deno.env.get`). This makes applying `014`
  (RLS hardening) the highest-value security item: the hosted Advisor still shows RLS **off** on
  core tables, which means the publicly-shipped key was effectively unrestricted.
- **`mobile/.env.example` converted to a deprecation pointer** at `dart_define.example.json`.
  `admin_dashboard/.env.example` is unaffected — that Vite app still uses `.env` legitimately.
- **Side effect of running `flutter pub get` on a Mac:** Flutter generated `mobile/ios/Podfile` and
  added the standard `#include?` CocoaPods lines to `ios/Flutter/{Debug,Release}.xcconfig`. Normal
  Flutter scaffolding, needed for the iOS/TestFlight path; safe to drop if unwanted.
- **Repaired two non-UTF-8 files** — `supabase/MIGRATIONS.md` (7× `0x97`) and
  `005_invites_user_properties_notifications_fix.sql` (5× `0x9d`), both mangled em-dashes. All five
  changes in `005` are inside `--` comments; no executable SQL touched.

### 2026-08-18 — Brain: site, iPad demo, TestFlight, RLS advisor

- Marketing site **https://relaxedlivingvalet.com** is live (not the Flutter app).
- iPad cannot use `localhost:8091`; same-Wi-Fi LAN IP until TestFlight.
- In-person install path: Apple Developer + Mac + Xcode → TestFlight (not public App Store first). Windows cannot build iOS.
- Hosted Advisor: RLS still **off** on core tables; 012–014 not applied. Stripe functions deployed; secrets still owner action.
- Clarified: Property Manager dashboard = apartment office; Owner = Relaxed Living.

### 2026-08-14 — Marketing site live

- Public site: **https://relaxedlivingvalet.com**
- App is still Flutter web on `localhost:8091` (PC only). iPad demo needs same Wi-Fi + computer LAN IP, or a hosted web build. Site is marketing, not the Flutter app.

### 2026-08-13 — Stripe Checkout for packs and paid comebacks

- Migration `015_stripe_payments.sql` — `payment_orders`; nullable `pickup_id`; Stripe session columns
- Edge functions: `create-checkout-session`, `stripe-webhook` fulfillment (credits + invoice row)
- Flutter: `StripeCheckout` helper; Extra Services packs + paid comeback open hosted Checkout
- Setup: `brain/stripe_setup.md` (keys, webhook URL, test card)
- Hosted migration applied via MCP (`stripe_payments`)

### 2026-08-10 — External AI handoff doc

- **`brain/handoff_for_external_ai.md`** — single paste for Claude / ChatGPT (product, creds, migrations, decisions, next steps)
- Marked LLC done; bank account still needed for Stripe
- Updated resume notes in `current_state.md` / `next_steps.md`

### 2026-07-12 — Brain refresh: ordered go-live playbook

- **Step 1** clarified as legal/business foundation (LLC, insurance, Privacy/Terms, contracts)
- **`go_live_checklist.md`** — Step 1 legal section before Phase 0 security
- **`next_steps.md`** — ordered Steps 1–6 (legal → RLS → QA → env → pilot → stores)
- **`current_state.md`** — resume sequence updated
- Removed obsolete `handoff_for_claude.md` / `project_handoff.md` from working tree

### 2026-05-19 — Go-live process started (`2f0c9b8`)

- **`brain/go_live_checklist.md`** — phased plan: demo → security → pilot → stores
- **`014_launch_rls_hardening.sql`** — RLS re-enable, `is_owner_admin()`, satellite policies
- **`supabase/tests/rls_role_smoke.sql`** — verification queries
- **`mobile/.env.example`** — staging/prod key separation notes
- Hosted apply via MCP timed out — apply 012–014 manually in Supabase SQL editor

### 2026-05-19 — Owner/Admin two-way quick switch (`8b5b8aa`)

- Added top quick switch bars on both dashboards:
  - Owner → Admin Portal
  - Admin Portal → Owner Dashboard
- Added Admin Tools switch tile back to Owner dashboard
- No credential changes; same Staff login/session

### 2026-05-19 — Brain refresh + GitHub push note (`eb29777` stack)

- Documented owner login, migrations 012–013, workforce QA, recent commits on `main`

### 2026-05-19 — Unify owner and super_admin login (`eb29777`)

- **`owner` and `super_admin`** both route to **Owner dashboard**; Admin Portal from More
- **Owner login:** `relaxedlivingtx@gmail.com` / `RelaxedLiving2026!` (Staff sign-in)
- Optional alias `relaxedlivingtx+owner@gmail.com`; migration `013_unify_owner_role.sql`
- `RoleTheme.fromString('owner')` fix; admin role picker includes `owner`

### 2026-05-19 — Workforce: OM timecards + owner labor estimates (`401b13e`)

- **`ClockHours`** helper — shift pairing, week/month hour totals, labor cost
- **`OmWorkforceScreen`** — OM Routes/More: on-duty, GPS sharing, shift history per worker
- **`OwnerWorkforceScreen`** — edit driver `hourly_rate` via `set_worker_hourly_rate` RPC
- **Owner Financials** — est labor week/month from clock × rate; net est subtracts labor
- **Migration `012_workforce_labor.sql`** — hourly_rate column, clock_events/worker_locations RLS
- **Worker Earnings** — refactored to shared `ClockHours`

### 2026-05-19 — GitHub push billing door counts (`48ec1cf`)

- Door-count billing UI, migration 011, brain refresh

### 2026-05-19 — Billing: enter total + occupied doors (auto-calc)

- **`billing_total_doors` / `billing_occupied_doors`** on properties (migration `011`)
- **Property Billing Rates** — inputs: total doors, occupied, $/door; live calc occupancy %, billable doors, monthly $
- PM/owner dashboards use saved door counts when set

### 2026-05-19 — Admin property billing rates screen

- **`AdminPropertyBillingScreen`** — edit `monthly_fee_per_door` and minimum billable % per property
- **Add Property** — billing fields on create
- **Tools** → Property Billing Rates

### 2026-05-19 — Brain refresh + GitHub push (financials, billing, invites)

- **Updated**: `current_state.md`, `next_steps.md`, `decisions.md`, `resident_invite_workflow.md`
- **Pushed**: owner Financials, PM occupancy/85% billing, staff role poll fix, invite playbook, migration 010

### 2026-05-19 — Owner financials + PM occupancy billing (85% rule)

- **Migration `010_property_billing_metrics`** — `monthly_fee_per_door`, `minimum_billable_occupancy_percent` (default 85%)
- **`PropertyBilling`** helper — billable doors, revenue per door
- **Owner Financials tab** — contract revenue, MRR, per-property revenue/door, Stripe payout list, CSV export
- **PM dashboard** — occupied/vacant per unit, billable doors, est. monthly bill with 85% minimum copy

### 2026-05-19 — Resident invite playbook + PM CSV export

- **`brain/resident_invite_workflow.md`** — how codes flow super admin → DB → PM dashboard → residents
- **PM Properties tab** — Export unit codes (CSV), per-unit copy; clarified auto-sync copy
- **Admin invite codes** — fixed `use_count` column (was `current_uses`, broke inserts on live DB)

### 2026-05-19 — Fix staff signup routing to resident dashboard

- **Root cause**: `auth.signUp` created a session before `register_staff_with_invite` finished; `RoleHome` read `users` once, got no row, defaulted to `resident` (DB profile was correct — e.g. `relaxedlivingtx+824@gmail.com` as `property_manager`).
- **Fix**: `fetchUserRole()` polls until profile exists; `RoleHome` no longer defaults to resident on missing profile; staff signup waits for role before navigating.

### 2026-05-19 — Staff invite codes (self-signup for PM / OM / driver)

- **Migration `009_staff_invites`** — applied live via Supabase MCP (`staff_invites` name)
- **RPCs** — `verify_staff_invite_code` (anon), `register_staff_with_invite` (authenticated); links `user_properties`, PM sets `company_id`, driver gets `worker_assignments`
- **Flutter** — `AdminStaffInvitesScreen` (Tools), `StaffSignupScreen`, login **Resident | Staff** buttons on `simple_auth_screen.dart`

### 2026-05-19 — Admin add property + manager assignments UI

- **`AdminAddPropertyScreen`** — create property + optional starter building/floor/unit
- **`AdminManagerAssignmentsScreen`** — link `property_manager` / `operations_manager` via `user_properties`; optional `company_id` for PM
- **Properties tab** — Add, Assign managers, Assign workers; per-property quick actions
- **Tools** — Add Property, Manager Assignments, Worker Assignments

### 2026-05-19 — Worker assignment UI + worker route property display

- **`AdminWorkerAssignmentsScreen`** — always-visible worker + property dropdowns and Assign button; fixes insert (no broken upsert); loads drivers/properties from Supabase
- **Admin Properties tab** — “Assign workers” header button + per-property assign icon
- **Worker Route tab** — lists assigned properties, multi-property chips, clock-in requires assignment; resident ON DUTY when clocked in at property

### 2026-05-19 — Fix extra services ghost taps / overlap

- **Cause**: `IndexedStack` kept all tabs in the tree; invisible service grid still received clicks on web. Home tab also duplicated the grid.
- **Fix**: Mount only the active tab (`switch`); split Extra Services into **Request Service** | **Buy Comebacks** segments; home uses a single CTA card; grid uses `Wrap` + fixed tile sizes.
- **Files**: `resident_dashboard_screen.dart`, `extra_services_grid.dart`

### 2026-05-19 — Pushed Session 15 to GitHub

- **Commit** `a53e5e4` on `main` — resident comebacks, dashboard UI fixes, migration 008, brain docs
- **Remote** `https://github.com/relaxedlivingvalet/valettrashmobile.git`

### 2026-05-19 — Brain refresh (resident retest state)

- **Updated**: `brain/current_state.md` (resume notes, retest checklist, migration table, key files, uncommitted warning), `architecture.md`, `decisions.md`, `next_steps.md`
- **Reason**: Single source of truth before client QA

### 2026-05-18 — Applied migration `008` to live Supabase

- **MCP** `resident_comeback_balance_service_time` on `airpwzzkyjqzeeqizvft`: `purchased_comeback_balance`, `preferred_time`, resident UPDATE policy on `resident_units`
- **Verified**: columns present in `information_schema`

### 2026-05-18 — Resident dashboard: comebacks, clock-in status, UI fixes

- **Comebacks**: 1 free/month (no rollover); `purchased_comeback_balance` on `resident_units` (rolls over); packs 1/$5, 3/$14, 5/$20 via `BuyExtraPickupsSection`
- **Worker status**: `clock_events` last event per property (clock_in → ON DUTY)
- **UI**: `IndexedStack` tabs; `ExtraServicesGrid` fixed height; bell → notifications; countdown hours-only; service window 6–10 PM default
- **Service requests**: required date + time; optional message default text; `preferred_time` column (migration 008)
- **Files**: `008_resident_comeback_balance_service_time.sql`, `resident_dashboard_screen.dart`, `resident_comeback_request_screen.dart`, `service_request_sheet.dart`, `extra_services_grid.dart`, `buy_extra_pickups_section.dart`, `comeback_pricing.dart`, brain + `MIGRATIONS.md`
- **Reason**: Resident dashboard business rules + tab glitch / submit fixes from client feedback

### 2026-05-18 — Applied `service_requests` migration to live Supabase

- **MCP migrations** on `airpwzzkyjqzeeqizvft`:
  1. `add_owner_user_role` — `ALTER TYPE user_role ADD VALUE 'owner'` (required; policies failed without it)
  2. `007_service_requests` — table, indexes, RLS, 4 policies
- **Files Modified**: `supabase/migrations/007_service_requests.sql` (prepend enum fix), `brain/current_state.md`, `brain/next_steps.md`, `brain/change_log.md`
- **Reason**: Unblock resident extra-service requests (was 404)

### 2026-05-18 — Supabase MCP live project audit

- **Verified via Cursor Supabase plugin** (`list_tables`, `list_migrations`, `get_advisors`) on project `airpwzzkyjqzeeqizvft`:
  - `service_requests` table **not present** — confirms blocker for resident extra-service workflow
  - `list_migrations` returned empty (migration history not synced to hosted DB)
  - Security advisors: 19 tables RLS-disabled; several tables have policies but RLS off
- **Files Modified**: `brain/current_state.md`, `brain/next_steps.md`, `brain/change_log.md`
- **Reason**: Document live DB truth vs repo assumptions before store submission

---

### 2026-05-17 — Session 13: Brand mockup alignment across all 5 dashboards

- **Files Modified** (5 parallel agents, no conflicts):
  - `manager_dashboard_screen.dart` (OM) — "Operations Overview" header + Today pill; Communities/Routes stat row; large On-Time %; Missed count; Service Completion chart switched to 0-100% completion rate y-axis
  - `worker_dashboard_screen.dart` — "Hello [name]" + "You have N stops today" header; donut center % text overlay; "N of M Stops Complete" label; Next Stop card showing next unit + property name
  - `resident_dashboard_screen.dart` — Property name + dropdown chevron in header; bell notification icon; "All Clear / No missed collections" status when no active run
  - `property_manager_dashboard_new.dart` — "Property Manager View" title + "All Properties" filter pill; Open Requests count card (queries pending comebacks); Work Orders placeholder; Announcements list from `community_announcements`; compliance/satisfaction moved below
  - `owner_dashboard_screen.dart` — "Portfolio Summary" + "This Month" filter pill; Service Savings card with month-over-month % delta; Resident Satisfaction with delta; both query prior-month data from Supabase

- **Colors**: All dashboards already used correct brand palette — no AppColors changes needed (#0A0A0A, #1A1A1A, #3A3A3A, #6B6B6B, #E5E5E5, #0A84FF)

- **Result**: `flutter test` — All tests passed. `flutter analyze` — 0 errors, 0 new warnings in any edited file.

---

### 2026-05-17 — Session 13: Comeback entry point restored + lint finalization

- **Files Modified**:
  - `resident_dashboard_screen.dart` — added `_buildComebackCard()` to Home tab ListView; reads `comeback_pickup_fee` from `properties` row in `_load()`; navigates to `ResidentComebackRequestScreen(freeRemain: _freeRemain, comebackFee: _comebackFee)`; fixed `curly_braces_in_flow_control_structures` lint in `_load()` catch block; added import for `resident_comeback_request_screen.dart`

- **Why**: Session 12 dashboard rebuild dropped the comeback quick-action tile that was wired in Session 8. The `ResidentComebackRequestScreen` existed but was unreachable from the UI.

- **Result**: `flutter analyze lib/features/resident/screens/resident_dashboard_screen.dart` → No issues found. Resident can now tap "Request a Comeback" from the Home tab.

---

### 2026-05-17 — Lint cleanup: warnings + async context bugs

- **Files Modified**:
  - `admin_dashboard_screen.dart` — removed 4 unused imports (`dart:math`, `role_theme.dart`, `glow_badge.dart`, `primary_button.dart`); fixed 4× `use_build_context_synchronously` with `if (!mounted) return;` guards
  - `resident_extra_services_screen.dart` — removed unused `supabase_flutter` import
  - `resident_service_calendar_screen.dart` — removed unused `supabase_flutter` import + dead `lastDayOfMonth` variable
  - `resident_services_screen.dart` — removed unused `supabase_flutter` import
  - `property_manager_dashboard_screen.dart` — removed unused `_email` field + dead `initState` assignment block
  - `manager_property_services_screen.dart` — removed unused `supabase_flutter` import

- **Result**: `flutter analyze lib/` — 0 errors, 0 actionable warnings. Only 2 remaining warnings are `signInWithIdToken is experimental` in `simple_auth_screen.dart` (Supabase-controlled API, not fixable on our end)

---

### 2026-05-17 — Session 12: Full dashboard rebuild (RLV brand sheet + Supabase integration)

- **Goal**: Complete rebuild of all 5 role dashboards to match brand mockups. No Stripe.

- **Files Created**:
  - `mobile/lib/core/widgets/bento_card.dart` — shared dark card (surface1 bg, 16px radius, border)
  - `mobile/lib/core/widgets/metric_tile.dart` — label (9px Inter caps) + value (28px Montserrat w800) + optional subtitle

- **Files Rebuilt** (all zero errors/warnings in `flutter analyze`):
  - `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` — Amazon Flex-style Scan tab (photo confirm OR manual mark done, flag comeback, auto-advance), fl_chart donut for stop progress, realtime direct messaging, clock in/out
  - `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — BentoCard 2×2 metrics, fl_chart 7-day LineChart for completion trend
  - `mobile/lib/features/owner/screens/owner_dashboard_screen.dart` — BentoCard metrics including "Earned from Comebacks" (completedComebacks × $15)
  - `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` — community health bento grid, Send Announcement bottom sheet → community_announcements table
  - `mobile/lib/features/resident/screens/resident_dashboard_screen.dart` — fixed subscribe() void result, isFilter → .filter(), removed unused import

- **Critical v1 patterns applied everywhere**:
  - `subscribe()` returns void — must separate from channel chain: `_channel = ...on(...); _channel?.subscribe();`
  - `.isFilter()` is v2-only — use `.filter('col', 'is', 'null')`

- **Verified**: `flutter analyze lib/` — 0 errors, 0 warnings in all 5 dashboard files; `flutter test` — All tests passed

---

### 2026-05-19 — Resident dashboard layout + service requests

- **Supabase**: `007_service_requests.sql` — `service_requests` table (service type, preferred date, message, status) + RLS for residents, owner, super_admin
- **Resident**: Home tab matches mock layout (pickup card, stats, quick actions, services grid, support bar); bottom nav **Support** replaces Messages; service request bottom sheet with dropdown + calendar
- **Admin**: Concerns tab → **Resident Inbox** with Concerns / Service Requests segments
- **Owner**: More tab → **Service Requests Inbox**
- **Files**: `resident_dashboard_screen.dart`, `service_request_sheet.dart`, `resident_concerns_screen.dart` (`ResidentSupportPanel`), `service_requests_inbox_screen.dart`, `admin_dashboard_screen.dart`, `owner_dashboard_screen.dart`

---

### 2026-05-17 — Final app icon

- **Files Modified**:
  - `mobile/assets/icon/app_icon.png`, `app_icon_foreground.png`, `splash_logo.png` — final RLV logo from owner
  - `mobile/pubspec.yaml` — adaptive icon background `#10B981` → `#000000`
  - Regenerated Android mipmaps/adaptive icons, iOS AppIcon, and native splash assets via `flutter_launcher_icons` + `flutter_native_splash`
  - `brain/next_steps.md`, `brain/current_state.md`

- **Reason**: Store submission checklist — replace placeholder icon with production artwork

---

### 2026-05-16 (Session 11 — Owner handoff prep)

- **Files Modified**:
  - `mobile/README.md` — full rewrite as owner handoff guide: feature walkthrough per role, test credentials, step-by-step App Store + Google Play submission guide, Supabase production config steps, future features list
  - `mobile/android/.gitignore` — commented out keystore/jks/key.properties exclusions so signing artifacts are committed (repo is private)
  - `brain/test_credentials.md` — fixed stale `owner` role mapping (was "falls through to resident", now correctly `OwnerDashboardScreen`)
  - `brain/current_state.md` — updated Known Issues to reflect `.env`, keystore, and `key.properties` are all committed

- **Committed to repo**: `mobile/android/upload-keystore.jks` and `mobile/android/key.properties` (previously gitignored)

---

### 2026-05-16 (Session 9 — super_admin account, password reset flow, visibility toggles)

- **DB changes** (Supabase dashboard):
  - Created auth user `relaxedlivingtx@gmail.com` (UID: `14e75f4c-29de-4516-b8d1-7bebe963535d`, pass: `RelaxedLiving2026!`) — business owner / super_admin
  - `INSERT INTO public.users ... role='super_admin'` for that UID
  - Supabase Auth → URL Configuration: Site URL updated to `http://localhost:8091`; `http://localhost:8091` added to Redirect URLs (previously no redirect URLs and wrong port 3000)

- **Files Created**:
  - `mobile/lib/features/auth/screens/change_password_screen.dart` — three-state screen: (1) "Send reset email" with email display, (2) email-sent confirmation with resend button, (3) "Set new password" form (isRecovery=true, launched from AuthGate passwordRecovery event). Password fields have visibility toggles.

- **Files Modified**:
  - `mobile/lib/valet_app.dart` — `AuthGate` StreamBuilder intercepts `AuthChangeEvent.passwordRecovery` → shows `ChangePasswordScreen(isRecovery: true)` before routing to role home
  - `mobile/lib/features/auth/screens/simple_auth_screen.dart` — password field now has `_obscurePassword` state + `suffixIcon` visibility toggle; `_darkField()` extended to accept `Widget? suffixIcon`
  - `mobile/lib/features/auth/screens/resident_signup_screen.dart` — password field has `_obscurePassword` state + visibility toggle; `_field()` helper extended with `VoidCallback? onToggleObscure`
  - `mobile/lib/features/resident/screens/resident_dashboard_screen.dart` — "Change Password" PrimaryButton added before Sign Out in Profile tab
  - `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` — "Change Password" PrimaryButton added before Sign Out in Profile tab
  - `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — "Change Password" PrimaryButton added before Sign Out in Profile tab
  - `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` — "Change Password" PrimaryButton added before Sign Out in Settings tab
  - `mobile/lib/features/admin/screens/admin_dashboard_screen.dart` — "Change Password" `_toolTile` added before Sign Out tile in Tools tab

- **Bug fixes**:
  - `change_password_screen.dart` line 78: `supabase.auth.update()` → `supabase.auth.updateUser()` (gotrue-1.12.6 API)

- **Verified**: `flutter build web --no-tree-shake-icons` → `✓ Built build/web` (clean, no errors)
- Added "Forgot password?" link on login screen (right-aligned, below password field, login mode only) → navigates to `ChangePasswordScreen`
- Created `brain/test_credentials.md` — all test accounts, passwords, role→screen mapping, test data

### 2026-05-16 (Session 10 — Owner routing fix + App Store / Play Store prep)

- **Owner routing**: Added `case 'owner':` in `RoleHome` switch → `OwnerDashboardScreen` (light theme). Previously fell through to resident dashboard.

- **Native platform generation**: Ran `flutter create --platforms=android,ios --org com.relaxedliving --project-name valet .`
  - Created `android/` and `ios/` directories
  - Bundle ID / applicationId: `com.relaxedliving.valet`

- **Android** (`android/app/`):
  - `build.gradle.kts` — minSdk 21, release signing via `key.properties`, R8 minification + resource shrinking enabled
  - `src/main/AndroidManifest.xml` — app label "Relaxed Living Valet", added CAMERA, READ_MEDIA_IMAGES, READ_EXTERNAL_STORAGE (maxSdk 32), WRITE_EXTERNAL_STORAGE (maxSdk 28), ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION permissions; deep link intent filter for `com.relaxedliving.valet://login-callback`
  - `app/proguard-rules.pro` — created with Flutter + Supabase/okhttp rules
  - `key.properties` + `upload-keystore.jks` generated (both gitignored); password: `RLValet2026!Key`

- **iOS** (`ios/Runner/Info.plist`):
  - `CFBundleDisplayName` / `CFBundleName` → "Relaxed Living Valet"
  - Added `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSLocationWhenInUseUsageDescription`
  - Added `CFBundleURLTypes` with scheme `com.relaxedliving.valet` for deep links
  - Portrait-only for phones (`UISupportedInterfaceOrientations`)

- **pubspec.yaml**: renamed package `mobile` → `valet`, updated description, added `flutter_launcher_icons ^0.14.3` and `flutter_native_splash ^2.4.3` dev deps with full config

- **App icons**: Created placeholder PNGs at `assets/icon/` (emerald circle with "RL" monogram, dark bg); ran `flutter pub run flutter_launcher_icons` — icons generated for Android (standard + adaptive) and iOS

- **Splash screen**: Configured dark background `#0A0C0F` with splash logo; ran `flutter pub run flutter_native_splash:create` — splash generated for Android (including API 31+) and iOS

- **Deep links**: 
  - `main.dart` — added `authCallbackUrlHostname: 'login-callback'` to `Supabase.initialize()`
  - `change_password_screen.dart` — platform-aware `redirectTo`: `null` on web, `com.relaxedliving.valet://login-callback` on mobile
  - Supabase Auth → Redirect URLs: added `com.relaxedliving.valet://login-callback` (Total: 2 URLs)

- **Verified**: `flutter build web --no-tree-shake-icons` → `✓ Built build/web` (clean after `flutter clean`)

---

### 2026-05-16 (Session 8 — Comeback Requests, Concerns, Admin Portal)

- **DB changes** (Supabase SQL editor):
  - `ALTER TABLE missed_pickup_requests ADD COLUMN IF NOT EXISTS is_free boolean DEFAULT true, payment_status text DEFAULT 'free', payment_amount_cents int, stripe_payment_intent_id text`
  - `ALTER TABLE properties ADD COLUMN IF NOT EXISTS free_comeback_pickups_per_month int DEFAULT 1, comeback_pickup_fee numeric(10,2) DEFAULT 15.00`
  - `CREATE TABLE resident_concerns (id uuid PK, resident_user_id uuid FK users, property_id uuid FK properties, subject text, message text, status text DEFAULT 'open', created_at timestamptz)` + RLS
  - `CREATE TABLE resident_monthly_usage (user_id uuid, year_month text, comeback_count int DEFAULT 0, PRIMARY KEY(user_id, year_month))` + RLS
  - Added `FOR ALL TO authenticated` admin RLS policies on `users`, `properties`, `resident_units`, `resident_concerns`, `missed_pickup_requests`, `invite_codes`, `worker_assignments`

- **Files Created**:
  - `mobile/lib/features/resident/screens/resident_comeback_request_screen.dart` — quota-aware comeback flow (1 free/month, Stripe-ready paid path with placeholder dialog, LottieSuccessView)
  - `mobile/lib/features/resident/screens/resident_concerns_screen.dart` — subject dropdown + message textarea, submits to resident_concerns, LottieSuccessView
  - `mobile/lib/features/admin/screens/admin_dashboard_screen.dart` — full 5-tab admin portal (Users, Properties, Residents, Concerns, Tools); inline `_AdminComebacksScreen` and `_AdminWorkerAssignmentsScreen`
  - `mobile/lib/features/admin/screens/admin_invite_codes_screen.dart` — per-property invite code list, generate sheet, copy/revoke actions

- **Files Modified**:
  - `mobile/lib/features/resident/screens/resident_dashboard_screen.dart` — replaced "Report Missed Pickup" with "Request a Comeback" + "Questions & Concerns" quick action tiles; loads free_comeback_pickups_per_month and resident_monthly_usage on init
  - `mobile/lib/features/auth/screens/resident_signup_screen.dart` — full dark redesign (was light mode); uses AppColors tokens, PrimaryButton, GlowBadge, dark field helper; business logic unchanged
  - `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` — added clock state restoration on login (queries clock_events for last event; if clock_in, sets _isOnDuty = true)
  - `mobile/lib/valet_app.dart` — added super_admin case routing to AdminDashboardScreen (AppTheme.light)

- **Verified** (2026-05-16): Admin portal end-to-end with super_admin role:
  - Users tab: 7 accounts loaded, role pills correct, edit sheet pre-fills all fields
  - Properties tab: 3 properties loaded with service window and comeback fee config
  - Residents tab: active assignments with property filter chips working
  - Concerns tab: Open/In Review/Resolved filters, empty state working
  - Tools tab: Invite Codes nav, Comeback Requests nav, Worker Assignments nav, Sign Out
  - Invite Codes sub-screen: property filter chips, empty state, generate sheet with pre-filled property/unit/max-uses/validity

---

### 2026-05-16 (Session 7 — Features + Tech Debt)
- **Change**: Implemented 4 new user-facing features and completed major tech debt cleanup.
- **DB changes** (Supabase SQL editor):
  - `ALTER TABLE resident_units ADD COLUMN IF NOT EXISTS is_on_hold boolean DEFAULT false, ADD COLUMN IF NOT EXISTS hold_note text`
  - `CREATE TABLE clock_events` (uuid PK, user_id, property_id, event_type CHECK IN ('clock_in','clock_out'), created_at) + RLS
  - `CREATE TABLE worker_locations` (user_id PK, property_id, latitude, longitude, updated_at) + RLS
- **Files Created**:
  - `mobile/lib/features/resident/screens/resident_vacation_hold_screen.dart` — toggle is_on_hold on resident_units
  - `mobile/lib/features/worker/screens/worker_earnings_screen.dart` — reads clock_events, computes weekly/monthly hours
  - `mobile/lib/features/manager/screens/pm_compliance_report_screen.dart` — nightly_runs history, date range, CSV export via dart:html
  - `mobile/lib/features/manager/screens/om_worker_map_screen.dart` — flutter_map + Supabase Realtime stream on worker_locations
  - `mobile/.env.example` — onboarding template for new developers
- **Files Modified**:
  - `resident_dashboard_screen.dart` — added Vacation Hold tile in Profile tab
  - `worker_dashboard_screen.dart` — _toggleDuty() persists to clock_events; _shareLocation() upserts to worker_locations; Earnings tile in Profile tab; Share Location button in Route tab; removed unused _propertyIds field
  - `property_manager_dashboard_new.dart` — added Compliance Reports section in Settings tab
  - `manager_dashboard_screen.dart` — added Live Worker Map button in Dashboard tab; deleted _legacyBuild() + _chip() + _actionTile() (569 lines)
  - `property_manager_dashboard_new.dart` — deleted _buildLegacyDashboard() (298 lines)
  - 23 dart files — replaced withOpacity() with withValues(alpha:) throughout (0 remaining)
  - `test_connection_screen.dart` — fixed supabaseUrl/supabaseKey removed in v2 API
- **Blocked**: supabase_flutter v1→v2 upgrade blocked by missing pub cache entries for app_links-7.0.0 and sign_in_with_apple_web; remains at v1.10.25.

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

### 2026-05-16 (Phases 2–5 — Full Dashboard Redesign)
- **Change**: Complete dark redesign of all 5 role dashboards. Each screen now has 4-tab bottom navigation, role-accented hero cards, stat tiles, skeleton loading, and dark surface system. Phase 5 polish adds Lottie animations and SharedAxisTransition page transitions.
- **Files Created**:
  - `mobile/lib/core/utils/page_transitions.dart` — `SharedAxisPageRoute` using `animations` package
  - `mobile/lib/core/widgets/lottie_feedback.dart` — `LottieSuccessView` + `LottieErrorView` widgets
  - `mobile/assets/lottie/success.json` — minimal Lottie success animation (circle + checkmark)
  - `mobile/assets/lottie/error.json` — minimal Lottie error animation (red circle + X with shake)
- **Files Rewritten**:
  - `mobile/lib/features/resident/screens/resident_dashboard_screen.dart` — 4-tab layout (Home/History/Alerts/Profile), emerald accent, pre-loads notifications
  - `mobile/lib/features/worker/screens/worker_dashboard_screen.dart` — 4-tab layout (Route/Comebacks/Violations/Profile), amber accent, SharedAxisPageRoute for Violation Report
  - `mobile/lib/features/worker/screens/violation_report_screen.dart` — multi-step wizard (0=photo, 1=type, 2=details, 3=confirm), LottieSuccessView on submit
  - `mobile/lib/features/owner/screens/owner_dashboard_screen.dart` — 4-tab layout (Overview/Properties/Analytics/Settings), purple accent, occupancy bars, role switcher
- **Files Significantly Modified**:
  - `mobile/lib/features/manager/screens/manager_dashboard_screen.dart` — added 4-tab layout; _DarkSectionLabel class added; SharedAxisPageRoute wired for Comebacks + Notify nav
  - `mobile/lib/features/manager/screens/property_manager_dashboard_new.dart` — added 4-tab layout; `Icons.door_front` → `Icons.meeting_room` fix
  - `mobile/lib/features/manager/screens/manager_alerts_screen.dart` — `const Text` with `.shade700` → non-const fix
  - `mobile/lib/features/manager/screens/property_manager_dashboard_screen.dart` — `Icons.door_front` → `Icons.meeting_room` fix
- **Result**: Zero analyzer errors, clean `flutter build web` output.
- **Reason**: Full redesign per spec in `docs/superpowers/specs/2026-05-16-valet-app-redesign-design.md`.

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

### 2026-05-16 (Session 6)
- **Change**: Ran schema migrations, implemented light mode for PM/Owner, completed all 4 "free" features from session 5.
- **DB changes** (Chrome automation → Supabase SQL editor):
  - `ALTER TABLE missed_pickup_requests ADD COLUMN IF NOT EXISTS notes text, ADD COLUMN IF NOT EXISTS photo_url text`
  - `ALTER TABLE properties ADD COLUMN IF NOT EXISTS latitude double precision, ADD COLUMN IF NOT EXISTS longitude double precision`
- **Light mode implementation** (`property_manager` and `super_admin` roles now default to light theme):
  - `core/theme/app_colors.dart` — added `AppColorsScheme` ThemeExtension (dark + light const instances) + `BuildContext.roleColors` extension
  - `core/theme/app_theme.dart` — added `AppTheme.light` using FlexColorScheme.light; both themes register `AppColorsScheme` extension
  - `valet_app.dart` — PM and Owner routes wrapped in `Theme(data: AppTheme.light, child: ...)`
  - `property_manager_dashboard_new.dart` — `_c = context.roleColors` via `didChangeDependencies`; all surface/text color refs use `_c.*`
  - `owner_dashboard_screen.dart` — same pattern; `_OwnerSectionLabel` uses `context.roleColors.textMuted`
  - `core/widgets/stat_tile.dart` — uses `context.roleColors` (theme-aware, adapts to light/dark)
  - `core/widgets/role_bottom_nav.dart` — uses `context.roleColors` (theme-aware)

### 2026-05-15
- **Change**: Installed Repo OS brain scaffold (brain/, .cursor/rules/, cursor-os/, scripts/).
- **Files Modified**: `brain/project_context.md`, `brain/architecture.md`, `brain/current_state.md`, `brain/decisions.md`, `brain/next_steps.md`, `brain/change_log.md`, `.cursor/rules/00-repo-brain.mdc` (+ 3 more rules), `cursor-os/` (6 docs), `scripts/init-cursor-os.js`, `README.md`
- **Reason**: Establish persistent project memory for resumable AI-assisted development sessions.
