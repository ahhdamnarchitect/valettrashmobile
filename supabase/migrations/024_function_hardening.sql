-- 024 - function hardening (Supabase Security Advisor).
--
-- 1. search_path. audit_trigger() is SECURITY DEFINER with no `SET search_path`.
--    That is a genuine escalation vector: whoever triggers the function controls
--    search_path, so an attacker-created `users` table earlier on the path could be
--    written to with the definer's privileges. handle_updated_at() is not SECURITY
--    DEFINER, but pinning it costs nothing and clears the linter.
--
-- 2. EXECUTE grants. The advisor flags every SECURITY DEFINER function as callable.
--    For the RLS helpers that is unavoidable and harmless - a policy can only be
--    evaluated if the querying role may execute the functions it calls, and each
--    returns just a boolean/NULL about the CALLER (verified: anon gets
--    is_owner_admin() = false, current_user_role() = NULL, no data disclosed).
--    For the rest, anon has no business calling them at all, so EXECUTE is revoked.

-- ---------------------------------------------------------------------------
-- 1. Pin search_path on the two flagged functions
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.audit_trigger()     SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_updated_at() SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------------
-- 2. Trigger functions must never be callable through the API
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.audit_trigger()     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_updated_at() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Privileged / signup RPCs: signed-in callers only, never anon.
--    Each authorizes internally as well (defence in depth) - set_worker_hourly_rate
--    raises 'not authorized' unless the caller is owner/super_admin, and the invite
--    functions are called immediately after signUp(), so a session always exists.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.set_worker_hourly_rate(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_worker_hourly_rate(uuid, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_invite_code(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_invite_code(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.register_staff_with_invite(uuid, uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_staff_with_invite(uuid, uuid, text, text, text) TO authenticated;

-- verify_* are read-only code lookups used before a session exists on the signup
-- screens, so anon keeps EXECUTE. They return only whether a code is valid.
