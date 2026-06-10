-- RLS smoke checks — run in Supabase SQL editor AFTER migration 014.
-- Replace :user_id with a test auth.users id when testing as a specific role.

-- 1) Tables without RLS (should return ZERO rows)
SELECT c.relname AS table_without_rls
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relrowsecurity = false
ORDER BY 1;

-- 2) Policy count per table
SELECT schemaname, tablename, COUNT(*) AS policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY 1, 2
ORDER BY 2;

-- 3) Helper functions exist
SELECT proname FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('is_owner_admin', 'is_staff_role', 'set_worker_hourly_rate');

-- 4) Owner account role check
SELECT email, role, is_active
FROM public.users
WHERE email IN (
  'relaxedlivingtx@gmail.com',
  'relaxedlivingtx+owner@gmail.com'
);

-- Manual app tests after RLS (checklist):
-- [ ] Resident signup with invite code
-- [ ] Staff signup with staff invite
-- [ ] Owner login → Financials + Admin Portal switch
-- [ ] PM sees only assigned property invite codes
-- [ ] Worker clock in/out + OM workforce view
