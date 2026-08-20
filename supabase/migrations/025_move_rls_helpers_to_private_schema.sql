-- 025 - move the RLS helper functions out of the API-exposed schema.
--
-- The Security Advisor flags every SECURITY DEFINER function in `public` as
-- callable through PostgREST. Revoking EXECUTE is NOT an option here: a policy is
-- evaluated as the querying role, so the role must be able to execute the functions
-- its policies call. Verified experimentally - revoking EXECUTE on can_access_*
-- immediately produced `permission denied for function can_access_floor` on every
-- units/buildings/floors read.
--
-- The supported fix is to move them to a schema PostgREST does not expose. Policies
-- still call them (EXECUTE is granted below); the REST API cannot reach them.
--
-- These helpers disclose nothing anyway - each returns a boolean/NULL about the
-- CALLER - but keeping the exposed surface minimal is the point.
--
-- Functions that stay in `public` on purpose: claim_invite_code,
-- register_staff_with_invite, verify_invite_code, verify_staff_invite_code and
-- set_worker_hourly_rate are called by the app over RPC, and each authorises
-- internally. audit_trigger/handle_updated_at stay because triggers reference them,
-- and 024 already revoked EXECUTE from every API role.

CREATE SCHEMA IF NOT EXISTS private;
GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1. Recreate the helpers in `private`, with internal references repointed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION private.current_user_role()
RETURNS public.user_role LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$ SELECT role FROM public.users WHERE id = auth.uid() $fn$;

CREATE OR REPLACE FUNCTION private.is_owner_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('owner','super_admin')) $fn$;

CREATE OR REPLACE FUNCTION private.is_staff_role(target text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$ SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role::text = target) $fn$;

CREATE OR REPLACE FUNCTION private.pm_has_property(prop uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT private.current_user_role() = 'property_manager'
       AND EXISTS (SELECT 1 FROM public.user_properties up
                   WHERE up.user_id = auth.uid() AND up.property_id = prop);
$fn$;

CREATE OR REPLACE FUNCTION private.resident_has_property(prop uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT EXISTS (SELECT 1 FROM public.resident_units
                   WHERE user_id = auth.uid() AND property_id = prop AND is_active = true);
$fn$;

CREATE OR REPLACE FUNCTION private.worker_has_property(prop uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT EXISTS (SELECT 1 FROM public.worker_assignments
                   WHERE user_id = auth.uid() AND property_id = prop AND is_active = true);
$fn$;

CREATE OR REPLACE FUNCTION private.pm_owns_unit(target_unit uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT private.current_user_role() = 'property_manager'
       AND EXISTS (
            SELECT 1 FROM public.units u
            JOIN public.floors f     ON f.id = u.floor_id
            JOIN public.buildings b  ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE u.id = target_unit AND p.company_id = auth.uid());
$fn$;

CREATE OR REPLACE FUNCTION private.can_access_property(prop uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT prop IS NOT NULL AND (
           private.is_owner_admin()
        OR private.is_staff_role('operations_manager')
        OR private.pm_has_property(prop)
        OR (private.current_user_role() = 'property_manager'
            AND EXISTS (SELECT 1 FROM public.properties p WHERE p.id = prop AND p.company_id = auth.uid()))
        OR private.worker_has_property(prop)
        OR private.resident_has_property(prop));
$fn$;

CREATE OR REPLACE FUNCTION private.can_access_building(bldg uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$ SELECT private.can_access_property((SELECT b.property_id FROM public.buildings b WHERE b.id = bldg)) $fn$;

CREATE OR REPLACE FUNCTION private.can_access_floor(flr uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$ SELECT private.can_access_building((SELECT f.building_id FROM public.floors f WHERE f.id = flr)) $fn$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA private TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Repoint every policy that calls a public.<helper> at private.<helper>.
--    Rebuilt from pg_policies so nothing is missed and nothing is hand-typed.
--    Runs in one transaction: any failure rolls the whole thing back.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    r      record;
    q      text;
    w      text;
    stmt   text;
    n      int := 0;
    -- pg_policies renders these unqualified (search_path includes public), e.g.
    -- `can_access_property(property_id)` - so match the bare name. Strip any explicit
    -- public. prefix first so the second pass cannot double-qualify.
    names  text := '(is_owner_admin|is_staff_role|current_user_role|pm_has_property|pm_owns_unit|resident_has_property|worker_has_property|can_access_property|can_access_building|can_access_floor)';
    pat    text;
BEGIN
    pat := '\m' || names || '\(';
    FOR r IN
        SELECT tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND (coalesce(qual,'') || ' ' || coalesce(with_check,'')) ~ pat
    LOOP
        q := regexp_replace(coalesce(r.qual, ''),       'public\.' || names || '\(', '\1(', 'g');
        w := regexp_replace(coalesce(r.with_check, ''), 'public\.' || names || '\(', '\1(', 'g');
        q := regexp_replace(q, pat, 'private.\1(', 'g');
        w := regexp_replace(w, pat, 'private.\1(', 'g');

        EXECUTE format('DROP POLICY %I ON public.%I', r.policyname, r.tablename);

        stmt := format('CREATE POLICY %I ON public.%I AS %s FOR %s TO %s',
                       r.policyname, r.tablename,
                       r.permissive, r.cmd,
                       array_to_string(r.roles, ', '));
        IF coalesce(r.qual, '') <> ''       THEN stmt := stmt || format(' USING (%s)', q); END IF;
        IF coalesce(r.with_check, '') <> '' THEN stmt := stmt || format(' WITH CHECK (%s)', w); END IF;

        EXECUTE stmt;
        n := n + 1;
    END LOOP;

    RAISE NOTICE 'repointed % policies to private helpers', n;
END $$;

-- ---------------------------------------------------------------------------
-- 3. Drop the now-unreferenced public copies.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.can_access_floor(uuid);
DROP FUNCTION IF EXISTS public.can_access_building(uuid);
DROP FUNCTION IF EXISTS public.can_access_property(uuid);
DROP FUNCTION IF EXISTS public.pm_owns_unit(uuid);
DROP FUNCTION IF EXISTS public.pm_has_property(uuid);
DROP FUNCTION IF EXISTS public.worker_has_property(uuid);
DROP FUNCTION IF EXISTS public.resident_has_property(uuid);
DROP FUNCTION IF EXISTS public.is_staff_role(text);
DROP FUNCTION IF EXISTS public.is_owner_admin();
DROP FUNCTION IF EXISTS public.current_user_role();
