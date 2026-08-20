-- 023 - one consistent access rule for the property -> building -> floor -> unit tree.
--
-- The three "Users can view X based on property access" policies (buildings, floors,
-- units) each re-implemented the same role check inline, and had two problems:
--
--   * Property managers were matched only by properties.company_id, so a PM assigned
--     through user_properties (what the app actually does) saw their property but
--     ZERO buildings, floors or units.
--   * Each policy JOINed up the hierarchy inside its USING clause while every table
--     in that JOIN carries its own RLS - the same nested-evaluation shape that made
--     violations time out (see 019).
--
-- Replaced with three SECURITY DEFINER helpers that walk the tree with RLS bypassed,
-- so evaluation is flat and cannot recurse. The access rule is now stated once, in
-- can_access_property(), and covers every role: owner tier, operations_manager,
-- property manager (either assignment mechanism), assigned worker, resident in the
-- property. Semantics are a superset of the old rule only for PM-via-user_properties
-- and operations_manager, both of which were bugs.

CREATE OR REPLACE FUNCTION public.can_access_property(prop uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT prop IS NOT NULL AND (
           public.is_owner_admin()
        OR public.is_staff_role('operations_manager')
        OR public.pm_has_property(prop)
        OR (public.current_user_role() = 'property_manager'
            AND EXISTS (SELECT 1 FROM public.properties p
                        WHERE p.id = prop AND p.company_id = auth.uid()))
        OR public.worker_has_property(prop)
        OR public.resident_has_property(prop)
    );
$fn$;

CREATE OR REPLACE FUNCTION public.can_access_building(bldg uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT public.can_access_property(
        (SELECT b.property_id FROM public.buildings b WHERE b.id = bldg)
    );
$fn$;

CREATE OR REPLACE FUNCTION public.can_access_floor(flr uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT public.can_access_building(
        (SELECT f.building_id FROM public.floors f WHERE f.id = flr)
    );
$fn$;

DROP POLICY IF EXISTS "Users can view buildings based on property access" ON public.buildings;
CREATE POLICY "Users can view buildings based on property access" ON public.buildings
    FOR SELECT USING (public.can_access_property(property_id));

DROP POLICY IF EXISTS "Users can view floors based on property access" ON public.floors;
CREATE POLICY "Users can view floors based on property access" ON public.floors
    FOR SELECT USING (public.can_access_building(building_id));

DROP POLICY IF EXISTS "Users can view units based on property access" ON public.units;
CREATE POLICY "Users can view units based on property access" ON public.units
    FOR SELECT USING (public.can_access_floor(floor_id));
