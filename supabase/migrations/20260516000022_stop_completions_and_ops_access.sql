-- 022 - missing table + the last two role-access gaps.
--
-- A. public.stop_completions did not exist in ANY migration, but
--    worker_dashboard_screen.dart both READS it (to filter finished stops out of
--    tonight's route) and INSERTS into it from _completeStop(). The read is wrapped
--    in `catch (_) {}` so it failed silently and every stop stayed "incomplete"
--    forever; the insert had no such guard and threw. This is the worker's core loop.
--
-- B. Property managers still could not read their own properties. The app assigns a
--    PM through public.user_properties, but the RLS policy only tested
--    properties.company_id. (Shipped as 021; re-stated here because it is idempotent
--    and this file is the one that must land.)
--
-- C. operations_manager had NO access to any operational table. The OM dashboard
--    reads users, worker_assignments, nightly_runs, missed_pickup_requests,
--    notifications, user_properties, properties, units, floors, buildings,
--    violations, resident_units, clock_events, worker_locations,
--    satisfaction_ratings and community_announcements - and saw zero rows in all of
--    them. operations_manager is internal staff for the service company, so it gets
--    read access across properties (not write; that stays owner-tier).

-- ---------------------------------------------------------------------------
-- A. stop_completions
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stop_completions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stop_id       UUID NOT NULL REFERENCES public.route_stops(id) ON DELETE CASCADE,
    run_id        UUID REFERENCES public.nightly_runs(id) ON DELETE SET NULL,
    completed_by  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    photo_url     TEXT,
    method        TEXT NOT NULL CHECK (method IN ('photo', 'manual', 'gps', 'skip')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (stop_id, run_id)
);

CREATE INDEX IF NOT EXISTS idx_stop_completions_run  ON public.stop_completions(run_id);
CREATE INDEX IF NOT EXISTS idx_stop_completions_stop ON public.stop_completions(stop_id);
CREATE INDEX IF NOT EXISTS idx_stop_completions_by   ON public.stop_completions(completed_by);

ALTER TABLE public.stop_completions ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.stop_completions IS
    'One row per route stop finished on a nightly run. Written by the worker app.';

DROP POLICY IF EXISTS "Workers manage own stop completions" ON public.stop_completions;
CREATE POLICY "Workers manage own stop completions" ON public.stop_completions
    FOR ALL TO authenticated
    USING (completed_by = auth.uid())
    WITH CHECK (completed_by = auth.uid());

DROP POLICY IF EXISTS "Owner admins manage stop completions" ON public.stop_completions;
CREATE POLICY "Owner admins manage stop completions" ON public.stop_completions
    FOR ALL TO authenticated
    USING (public.is_owner_admin())
    WITH CHECK (public.is_owner_admin());

DROP POLICY IF EXISTS "Ops managers read stop completions" ON public.stop_completions;
CREATE POLICY "Ops managers read stop completions" ON public.stop_completions
    FOR SELECT TO authenticated
    USING (public.is_staff_role('operations_manager'));

-- ---------------------------------------------------------------------------
-- B. Property manager -> properties, via user_properties OR company_id
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pm_has_property(prop uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT public.current_user_role() = 'property_manager'
       AND EXISTS (
            SELECT 1 FROM public.user_properties up
            WHERE up.user_id = auth.uid() AND up.property_id = prop
       );
$fn$;

DROP POLICY IF EXISTS "Property managers can view assigned properties" ON public.properties;
CREATE POLICY "Property managers can view assigned properties" ON public.properties
    FOR SELECT USING (
        public.pm_has_property(id)
        OR (public.current_user_role() = 'property_manager' AND company_id = auth.uid())
    );

-- ---------------------------------------------------------------------------
-- C. operations_manager - cross-property READ access to operational tables
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'properties','buildings','floors','units','resident_units','worker_assignments',
        'routes','route_stops','nightly_runs','pickups','missed_pickup_requests',
        'violations','user_properties','invite_codes','service_requests',
        'resident_monthly_usage','subscriptions','invoices'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'Ops managers read ' || t, t);
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated USING (public.is_staff_role(%L))',
            'Ops managers read ' || t, t, 'operations_manager');
    END LOOP;
END $$;
