-- 028 - workers could never file a violation.
--
-- violation_report_screen.dart resolves the resident of a unit before inserting:
--
--     select user_id from resident_units where unit_id = ? and is_active
--     -> if null: "No active resident mapped to this unit."
--
-- No policy on resident_units covered the driver role (only the resident themselves,
-- property managers, and super_admin), so that lookup returned NULL for every worker
-- and the screen bailed out every time. Verified live: a worker resolving unit 104,
-- which does have an active resident, got zero rows.
--
-- Reporting violations is core to the service, so a worker needs to see the resident
-- mapping for the properties they are actually assigned to - and nothing beyond that.
-- private.worker_has_property() is SECURITY DEFINER, so this does not re-enter the
-- resident_units policies (see 018).

DROP POLICY IF EXISTS "Workers view resident units for assigned properties" ON public.resident_units;
CREATE POLICY "Workers view resident units for assigned properties"
    ON public.resident_units FOR SELECT TO authenticated
    USING (
        private.current_user_role() = 'driver'
        AND private.worker_has_property(property_id)
    );

-- Same lookup, same reason: the screen reads the most recent pickup for the unit to
-- attach the violation to it.
DROP POLICY IF EXISTS "Workers view pickups for assigned properties" ON public.pickups;
CREATE POLICY "Workers view pickups for assigned properties"
    ON public.pickups FOR SELECT TO authenticated
    USING (
        private.current_user_role() = 'driver'
        AND EXISTS (
            SELECT 1 FROM public.units u
            JOIN public.floors f     ON f.id = u.floor_id
            JOIN public.buildings b  ON b.id = f.building_id
            WHERE u.id = pickups.unit_id
              AND private.worker_has_property(b.property_id)
        )
    );
