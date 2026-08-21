-- 030 - performance: short-circuit private.pm_has_unit() for non-PMs.
--
-- Measured against the live API: a RESIDENT reading violations took 1.87s, while
-- every other role/table combination sat at 0.30-0.57s. Not a missing index --
-- idx_units_floor_id, idx_floors_building_id, idx_buildings_property_id and
-- idx_violations_unit_id all exist.
--
-- The cause is pm_has_unit(), added in 029 without a role guard. RLS ORs every
-- policy together, so a resident's read still evaluates the property-manager
-- policies, and pm_has_unit() ran its four-table join (units -> floors -> buildings
-- -> properties) for every candidate row before the inner pm_has_property() finally
-- rejected them on role. pm_owns_unit() in 019 was written with the guard first and
-- does not have this problem.
--
-- Hoisting the role test is provably semantics-preserving: pm_has_property(), which
-- this function already calls inside the join, itself requires
-- current_user_role() = 'property_manager'. Any caller that fails the new guard would
-- have failed the inner one anyway -- it just fails before doing the join instead of
-- after.

CREATE OR REPLACE FUNCTION private.pm_has_unit(target_unit uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $fn$
    SELECT private.current_user_role() = 'property_manager'
       AND EXISTS (
            SELECT 1
            FROM public.units u
            JOIN public.floors f    ON f.id = u.floor_id
            JOIN public.buildings b ON b.id = f.building_id
            WHERE u.id = target_unit
              AND private.pm_has_property(b.property_id)
       );
$fn$;

GRANT EXECUTE ON FUNCTION private.pm_has_unit(uuid) TO anon, authenticated, service_role;

-- resident_has_property() is deliberately left unguarded. Guarding it on
-- role = 'resident' would deny a worker who also LIVES at a property access to their
-- own home unless they happened to be assigned to service it. It is a single indexed
-- lookup on resident_units, so it is not the cost here anyway.

-- Supports that lookup and the resident policies generally.
CREATE INDEX IF NOT EXISTS idx_resident_units_user_property_active
    ON public.resident_units(user_id, property_id) WHERE is_active = true;
