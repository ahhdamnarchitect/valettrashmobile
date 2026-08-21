-- Corrective migration for databases that already applied 004_rls_policies.
-- Fresh installs get this from the corrected 004; re-running here is harmless.
--
-- `Super admins can manage all users` is a policy ON public.users whose USING
-- clause selected FROM public.users. Postgres must evaluate the policy to answer
-- the subquery, which re-enters the same policy:
--     42P17: infinite recursion detected in policy for relation "users"
-- Any read touching public.users returned HTTP 500 — directly, or indirectly via
-- a policy on another table that joins users. That is effectively the whole app.
--
-- public.current_user_role() is SECURITY DEFINER, so its read of public.users
-- bypasses RLS and cannot recurse. Same for public.is_owner_admin() in 014.

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT role FROM public.users WHERE id = auth.uid()
$fn$;

DROP POLICY IF EXISTS "Super admins can manage all users" ON public.users;
CREATE POLICY "Super admins can manage all users" ON public.users
    FOR ALL USING (public.current_user_role() = 'super_admin');
