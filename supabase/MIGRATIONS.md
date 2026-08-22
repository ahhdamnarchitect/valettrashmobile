# Supabase migration order

`supabase/migrations/` is now the single source of truth and is **safe to run top to
bottom**. Files use Supabase's `<14-digit timestamp>_name.sql` convention so the
GitHub integration can apply them in order.

## Applying to a fresh project

Either connect the GitHub integration (below), or run `supabase/provision/`
parts 1 → 2 → 3 → 4a → 4 → 5 → 6 in the SQL editor. Parts 1 and 2 must be separate
executions — see the enum note.

## The chain (32 migrations)

| Version | What |
|---|---|
| `20260516000001` | `initial_schema` |
| `20260516000002` | `rls_policies` |
| `20260516000003` | `invites_user_properties_notifications_fix` |
| `20260516000004` | `storage_violations` |
| `20260516000005` | `enum_owner` |
| `20260516000006` | `service_requests` |
| `20260516000007` | `resident_comeback_balance_service_time` |
| `20260516000008` | `enum_operations_manager` |
| `20260516000009` | `staff_invites` |
| `20260516000010` | `property_billing_metrics` |
| `20260516000011` | `property_door_counts` |
| `20260516000012` | `workforce_labor` |
| `20260516000013` | `unify_owner_role` |
| `20260516000014` | `launch_rls_hardening` |
| `20260516000015` | `stripe_payments` |
| `20260516000016` | `audit_trigger_system_actions` |
| `20260516000017` | `fix_users_policy_recursion` |
| `20260516000018` | `fix_properties_policy_recursion` |
| `20260516000019` | `fix_violations_policy_performance` |
| `20260516000020` | `security_audit_logs_and_owner_access` |
| `20260516000021` | `pm_property_access_via_user_properties` |
| `20260516000022` | `stop_completions_and_ops_access` |
| `20260516000023` | `property_hierarchy_access` |
| `20260516000024` | `function_hardening` |
| `20260516000025` | `move_rls_helpers_to_private_schema` |
| `20260516000026` | `resident_units_immutability` |
| `20260516000027` | `storage_policy_roles` |
| `20260516000028` | `worker_resident_lookup` |
| `20260516000029` | `pm_access_via_user_properties` |
| `20260516000030` | `pm_has_unit_role_guard` |
| `20260516000031` | `rls_initplan_optimization` |
| `20260516000032` | `correct_monthly_fee_per_door_default` |

## Two structural rules this layout enforces

**Enum values get their own migration.** Postgres will not allow a new enum value to
be *used* in the transaction that added it, and both the GitHub integration and the
SQL editor run one transaction per execution. `service_requests` and `staff_invites`
originally added `owner` / `operations_manager` and then referenced them in the same
file, which aborted the whole migration — the defect that meant RLS was never actually
live. The `_enum_owner` and `_enum_operations_manager` files exist solely to land those
ALTERs and commit.

**`_deprecated/` is never applied.** These 7 files are legacy duplicates or
alternate shapes that conflict with the real chain. They are kept for history only and
sit outside the glob the integration reads:

- `000_enums.sql`
- `001_tables.sql`
- `002_indexes.sql`
- `002_notifications.sql`
- `002_rls_policies.sql`
- `003_notifications_v2.sql`
- `003_triggers_functions.sql`

## GitHub integration

Connect at **Project Settings → Integrations → GitHub** on the Supabase dashboard,
pointing at `relaxedlivingvalet/valettrashmobile`, production branch `main`.

⚠️ **Run `provision/backfill_migration_history.sql` first, once.** Every migration on
this project was applied as raw SQL through the editor, so
`supabase_migrations.schema_migrations` did not exist and Supabase believed nothing had
been applied. Connecting in that state would re-run all 31 against a database
that already has them. The backfill records them as applied; it creates no schema
objects and touches no data.

## Seed data

⚠️ **Do not run `seed_data/` in numeric order.** `001_seed_users.sql` inserts hardcoded
UUIDs, but `public.users.id` is a foreign key to `auth.users(id)`, so every insert fails
with no matching auth user — and `004`–`009` reference those same fake UUIDs. Use
`provision/part4_accounts_and_demo_data.sql`, which keys profile rows to real auth UUIDs
by email lookup.

| Seed | Safe? | Why |
|---|---|---|
| `001_seed_users.sql` | ❌ | fake UUIDs, FK violation |
| `002_seed_properties.sql` | ⚠️ | only with `company_id` nulled (part 4 does this) |
| `003_seed_units.sql` | ✅ | no user references |
| `004`–`009` | ❌ | reference the fake user UUIDs |
| `010_seed_invite_codes.sql` | ✅ | property/unit only. Code `WELCOME104` |

## Edge Functions

See **`brain/stripe_setup.md`**.

```
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook --no-verify-jwt
supabase secrets set STRIPE_SECRET_KEY=sk_test_...
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
supabase secrets set APP_ORIGIN=http://localhost:8091
```

`stripe-webhook` must keep JWT verification **off** — Stripe calls it without a
Supabase token and authenticates via the signature header instead.
