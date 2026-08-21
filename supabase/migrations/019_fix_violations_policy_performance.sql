-- Corrective migration: `violations` was unreadable (57014 statement timeout).
--
-- "Property managers can view violations for their properties" JOINs
-- units -> floors -> buildings -> properties inside its USING clause. Each of
-- those four tables carries its own multi-branch RLS policies, which reference
-- users, resident_units, worker_assignments, floors and buildings in turn. So a
-- single read of violations expands into a deeply nested tree of policy
-- evaluations — enough to blow the statement timeout even with zero rows.
--
-- Routing the ownership test through a SECURITY DEFINER helper collapses that to
-- one plain join with RLS bypassed. The role check is preserved exactly:
-- the caller must still be a property_manager who owns the property.

CREATE OR REPLACE FUNCTION public.pm_owns_unit(target_unit uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT public.current_user_role() = 'property_manager'
       AND EXISTS (
            SELECT 1
            FROM public.units u
            JOIN public.floors f     ON f.id = u.floor_id
            JOIN public.buildings b  ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE u.id = target_unit
              AND p.company_id = auth.uid()
       );
$fn$;

DROP POLICY IF EXISTS "Property managers can view violations for their properties" ON public.violations;
CREATE POLICY "Property managers can view violations for their properties" ON public.violations
    FOR SELECT USING (public.pm_owns_unit(unit_id));
