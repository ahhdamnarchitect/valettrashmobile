-- 029 - the property manager dashboard was blind on every operational table.
--
-- 021/023 fixed properties, buildings, floors and units. Ten more tables still
-- identified a PM only by `properties.company_id = auth.uid()`, but the app assigns
-- property managers through public.user_properties (admin_manager_assignments_screen
-- upserts there; manager_dashboard_screen and property_manager_dashboard_new read
-- from it). company_id is documented in that same screen as an OPTIONAL extra.
--
-- Verified live: a PM assigned to Sunset Gardens through user_properties saw
-- resident_units = 0 and violations = 0 for their own property, which empties the
-- compliance report, the alerts screen and the occupancy billing view.
--
-- These are additive SELECT policies - RLS policies are OR'd, so the existing
-- company_id route keeps working for anyone set up that way. private.pm_has_property()
-- is SECURITY DEFINER, so none of this re-enters the policy system (see 018).

-- Direct property_id -------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'resident_units','worker_assignments','routes','nightly_runs',
        'resident_monthly_usage','subscriptions','invoices'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', 'PM assigned via user_properties reads ' || t, t);
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR SELECT TO authenticated '
            'USING (private.pm_has_property(property_id))',
            'PM assigned via user_properties reads ' || t, t);
    END LOOP;
END $$;

-- Reached through unit -> floor -> building -> property ---------------------------
CREATE OR REPLACE FUNCTION private.pm_has_unit(target_unit uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT EXISTS (
        SELECT 1
        FROM public.units u
        JOIN public.floors f    ON f.id = u.floor_id
        JOIN public.buildings b ON b.id = f.building_id
        WHERE u.id = target_unit
          AND private.pm_has_property(b.property_id)
    );
$fn$;
GRANT EXECUTE ON FUNCTION private.pm_has_unit(uuid) TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "PM assigned via user_properties reads pickups" ON public.pickups;
CREATE POLICY "PM assigned via user_properties reads pickups"
    ON public.pickups FOR SELECT TO authenticated
    USING (private.pm_has_unit(unit_id));

DROP POLICY IF EXISTS "PM assigned via user_properties reads violations" ON public.violations;
CREATE POLICY "PM assigned via user_properties reads violations"
    ON public.violations FOR SELECT TO authenticated
    USING (private.pm_has_unit(unit_id));

DROP POLICY IF EXISTS "PM assigned via user_properties reads route_stops" ON public.route_stops;
CREATE POLICY "PM assigned via user_properties reads route_stops"
    ON public.route_stops FOR SELECT TO authenticated
    USING (private.pm_has_unit(unit_id));

-- Reached through the parent pickup -----------------------------------------------
DROP POLICY IF EXISTS "PM assigned via user_properties reads missed pickups" ON public.missed_pickup_requests;
CREATE POLICY "PM assigned via user_properties reads missed pickups"
    ON public.missed_pickup_requests FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            WHERE p.id = missed_pickup_requests.pickup_id
              AND private.pm_has_unit(p.unit_id)
        )
    );
