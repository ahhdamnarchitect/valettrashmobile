# Supabase migration order

Use **one** baseline for schema, then layer fixes.

---

## Provisioning a fresh project (start here)

For an empty project, run the four bundles in `supabase/provision/` in order. They
are generated from the files below with the ordering traps already handled:

| Run | File | What it does |
|---|---|---|
| 1 | `provision/part1_baseline.sql` | `001_initial_schema.sql` — enums, tables, indexes, triggers |
| 2 | `provision/part2_enum_values.sql` | **Run alone, let it commit.** Adds `owner` + `operations_manager` to `user_role` |
| 3 | `provision/part3_features_and_rls.sql` | `004` → `025`, minus the two `ALTER TYPE` lines |
| 4 | `provision/part4a_auth_users.sql` | Demo auth users (email + password + identity rows) |
| 5 | `provision/part4_accounts_and_demo_data.sql` | Profile rows keyed to those auth ids + property/unit/invite data |
| 6 | `provision/part5_demo_assignments.sql` | Wires PM / worker / resident to Sunset Gardens |

### Two traps these bundles work around

**1. Enum values cannot be added and used in the same transaction.**
`007_service_requests.sql` adds `'owner'` and then references it in a policy;
`009_staff_invites.sql` does the same with `'operations_manager'`. Postgres rejects
this with `unsafe use of new value "owner" of enum type user_role`, and the Supabase
SQL editor runs each execution as a single transaction. That is why part 2 exists and
must finish before part 3 starts.

**2. `seed_data/001_seed_users.sql` cannot run on a fresh project.**
It inserts hardcoded UUIDs (`00000000-…-0001` etc.), but `public.users.id` is a
foreign key to `auth.users(id)`. With no matching auth user, every insert fails.
Seeds `004`–`009` reference those same fake UUIDs and fail the same way. Create the
auth users in the Dashboard first, then use part 4, which keys profile rows to the
real auth UUIDs by email lookup.

### Four defects found and fixed while provisioning (2026-08-19)

All four were latent in the repo from the start. Each one aborts the migration or
breaks the API outright, which is why RLS was never actually live on the old project.
Migrations `016`–`019` patch a database that already ran `001`/`004`; the corrected
`001` and `004` cover fresh installs.

| # | Where | Symptom | Fix |
|---|---|---|---|
| 1 | `004` — `Users can update own profile` | `42P01: missing FROM-clause entry for table "old"` — `OLD` is trigger-only syntax and is invalid in an RLS policy. Aborted the whole RLS migration. | `WITH CHECK` against `public.current_user_role()` |
| 2 | `001` — `audit_trigger()` + `audit_logs.user_id` | `42703: record "new" has no field "created_by"` (PL/pgSQL resolves every `NEW.<field>`, and no audited table has `created_by`), then `23502` because `user_id` was `NOT NULL` but system actions have no actor. **Every INSERT** into the 7 audited tables failed. | read fields via `to_jsonb(NEW)`; make `user_id` nullable (`016`) |
| 3 | `004` — policies on `users` and `properties` | `42P17: infinite recursion detected in policy` — a policy on `users` selected `FROM users`, and `properties` ↔ `resident_units` / `worker_assignments` formed two mutual cycles. Core tables returned HTTP 500. | `SECURITY DEFINER` helpers (`017`, `018`) |
| 4 | `004` — PM violations policy | `57014: statement timeout` on an **empty** table — the policy JOINs `units→floors→buildings→properties`, each carrying its own multi-branch RLS. | `public.pm_owns_unit()` helper (`019`) |

### Security audit findings (2026-08-19)

Found by probing the live API as real logged-in users, not by reading code.

| Severity | Finding | Fix |
|---|---|---|
| **HIGH — confirmed exploitable** | `audit_logs` was readable by ANY authenticated user (`USING (auth.uid() IS NOT NULL)`). It stores `row_to_json()` snapshots of every change to properties, units, resident_units, violations and subscriptions. A resident test account read all 67 rows, including property billing rates. | `020` — owner tier only |
| **HIGH — broke the app** | 22 admin policies still tested `role = 'super_admin'` after `013` made `owner` canonical, and `014` covered only 3 tables. The business owner logged in and saw 0 units, 0 buildings, 0 routes, 0 invoices. | `020` — widened to `is_owner_admin()` |
| **MED** | `audit_trigger()` was `SECURITY DEFINER` with no `SET search_path` — a definer-privilege escalation vector. | `024` |
| **MED** | Property managers assigned via `user_properties` (what the app does) could not read their own properties, buildings, floors or units. | `021`, `023` |
| **MED** | `operations_manager` had no access to any operational table. | `022` |
| **MED** | `stop_completions` was queried and written by the worker app but **did not exist** in any migration. | `022` |
| **LOW** | Every RLS helper was callable through PostgREST. Revoking EXECUTE is impossible (policies need it — verified: it produces `permission denied for function`), so they moved to a non-exposed `private` schema. | `025` |

**Verified after fixes:** Supabase Security Advisor **0 errors, 8 warnings** (down from 35).
All 8 remaining are by design: `verify_invite_code` / `verify_staff_invite_code` must be
anon-callable (signup checks a code before a session exists); `claim_invite_code`,
`register_staff_with_invite` and `set_worker_hourly_rate` are app RPCs that each
authorise internally; leaked-password protection is Pro-plan only.

Role matrix confirmed against the live REST API:

| Table | owner | ops mgr | PM | worker | resident |
|---|---|---|---|---|---|
| properties | 2 | 2 | 1 | 1 | 1 |
| buildings | 5 | 5 | 3 | 3 | 3 |
| units | 56 | 56 | 40 | 40 | 40 |
| audit_logs | 69 | 0 | 0 | 0 | 0 |

Attack probes (as a resident): role escalation → `42501`, property insert → `42501`,
`set_worker_hourly_rate` → `not authorized`, other users' rows → own row only,
anon reads → `[]`.

**Why `SECURITY DEFINER` helpers.** A policy that reads a table with RLS re-enters the
policy system. Postgres either detects a cycle (`42P17`) or grinds through a deeply
nested plan (`57014`). A `STABLE SECURITY DEFINER` function bypasses RLS on its own
read, so it terminates. `014` already used this shape for `is_owner_admin()`; `017`–`019`
extend it to `current_user_role()`, `resident_has_property()`, `worker_has_property()`
and `pm_owns_unit()`. Access semantics are unchanged in every case.

**Verified after applying:** 32 tables, RLS on all 32, 101 policies, and all 28 REST
endpoints return `200` with the publishable key — while anon reads return `[]` against
seeded rows and anon writes are rejected with `42501`.

---

## Recommended path (reference — what the bundles contain)

1. `migrations/001_initial_schema.sql` — base schema, enums, tables, triggers
2. **`ALTER TYPE public.user_role ADD VALUE 'owner'` / `'operations_manager'`** — alone, committed
3. `migrations/004_rls_policies.sql` — row level security
4. `migrations/005_invites_user_properties_notifications_fix.sql` — invites, `user_properties`, notification broadcast, user self-insert policy, optional `pickup_id` on violations
5. `migrations/006_storage_violations.sql` — Storage bucket + policies
6. `migrations/007_service_requests.sql` — extra-service requests (Moving, Maid, Bulk) + RLS for resident / owner / super_admin
7. `migrations/008_resident_comeback_balance_service_time.sql` — `resident_units.purchased_comeback_balance`, `service_requests.preferred_time`, resident UPDATE policy for banked comebacks
8. `migrations/009_staff_invites.sql` — staff invite self-signup + admin assignment
9. `migrations/010_property_billing_metrics.sql` — fee per door + 85% minimum billable occupancy
10. `migrations/011_property_door_counts.sql` — manual `billing_total_doors` / `billing_occupied_doors`
11. `migrations/012_workforce_labor.sql` — OM timecards, clock events, owner labor estimates
12. `migrations/013_unify_owner_role.sql` — collapses `super_admin` into `owner` for the primary login
13. `migrations/014_launch_rls_hardening.sql` — go-live RLS pass; run `tests/rls_role_smoke.sql` after
14. `migrations/015_stripe_payments.sql` — Stripe checkout + webhook tables
15. `migrations/016_audit_trigger_system_actions.sql` — audit trigger + nullable `audit_logs.user_id`
16. `migrations/017_fix_users_policy_recursion.sql` — breaks `users` self-recursion
17. `migrations/018_fix_properties_policy_recursion.sql` — breaks the two `properties` cycles
18. `migrations/019_fix_violations_policy_performance.sql` — collapses the nested PM violations check

**GitHub integration:** If the Supabase project is linked to this repo
(`relaxedlivingvalet/valettrashmobile`), new files under `supabase/migrations/` are
applied on deploy when you push to the production branch. Check **Database → Migrations**
in the [dashboard](https://supabase.com/dashboard/project/immiejqvnucndjspacwv) for
pending/applied status. **Re-link this integration to the new project** — it still points
at the old one until you do.

## Do not run these

Legacy duplicates of `001_initial_schema` + `004_rls_policies`:

- `000_enums.sql`, `001_tables.sql`, `002_rls_policies.sql`
- `002_notifications.sql`, `003_notifications_v2.sql` — alternate notifications shape; the app targets `001_initial_schema.notifications` + migration `005`
- `002_indexes.sql` — byte-identical index set to `001_initial_schema`, and it has **no** `IF NOT EXISTS` guards, so it errors on an already-provisioned DB
- `003_triggers_functions.sql` — identical function set to `001_initial_schema`

## Seed data

⚠️ **Do not "run seeds in numeric order."** Only these three are safe on a fresh
project, and part 4 already includes them:

| Seed | Safe? | Why |
|---|---|---|
| `001_seed_users.sql` | ❌ | Fake UUIDs, no matching `auth.users` rows → FK violation |
| `002_seed_properties.sql` | ⚠️ | Safe only with `company_id` nulled (part 4 does this) |
| `003_seed_units.sql` | ✅ | No user references |
| `004`–`009` | ❌ | All reference the fake user UUIDs from `001_seed_users` |
| `010_seed_invite_codes.sql` | ✅ | Property/unit references only. Code `WELCOME104` |

To load `004`–`009` later, their user UUIDs must first be remapped to real `auth.users` ids.

## Edge Functions

See **`brain/stripe_setup.md`**.

```
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook --no-verify-jwt
supabase secrets set STRIPE_SECRET_KEY=sk_test_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
supabase secrets set APP_ORIGIN=http://localhost:8091
```

Also apply `015_stripe_payments.sql` before first checkout.
