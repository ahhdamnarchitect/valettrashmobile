# Supabase migration order

Use **one** baseline for schema, then layer fixes.

## Recommended path (full app)

1. `migrations/001_initial_schema.sql` — base schema, enums, tables, triggers  
2. `migrations/004_rls_policies.sql` — row level security  
3. `migrations/005_invites_user_properties_notifications_fix.sql` — invites, `user_properties`, notification broadcast, user self-insert policy, optional `pickup_id` on violations  
4. `migrations/006_storage_violations.sql` — Storage bucket + policies  
5. `migrations/007_service_requests.sql` — extra-service requests (Moving, Maid, Bulk, etc.) + RLS for resident / owner / super_admin  
6. `migrations/008_resident_comeback_balance_service_time.sql` — `resident_units.purchased_comeback_balance`, `service_requests.preferred_time`, resident UPDATE policy for banked comebacks  

**GitHub integration:** If the Supabase project is linked to this repo (`relaxedlivingvalet/valettrashmobile`), new files under `supabase/migrations/` are applied on deploy when you push to the production branch. Check **Database ? Migrations** in the [dashboard](https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft) for pending/applied status.

Skip these if you used `001_initial_schema` (they duplicate or conflict):

- `000_enums.sql`, `001_tables.sql`, `002_rls_policies.sql` (legacy duplicate of 001+004)  
- `002_notifications.sql`, `003_notifications_v2.sql` (alternate notifications shape; app targets `001_initial_schema.notifications` + migration 005)

Optional performance / extras (if not already in your baseline):

- `002_indexes.sql`  
- `002_notifications.sql` — **do not combine** with `001_initial_schema.notifications` without reconciliation  
- `003_triggers_functions.sql`  

## Seed data

Run seeds in numeric order under `seed_data/`. After invites migration, run `010_seed_invite_codes.sql` for a sample code (`WELCOME104`).

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
