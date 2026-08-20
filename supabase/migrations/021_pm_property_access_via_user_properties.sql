-- 021 - property managers could not see the properties they were assigned.
--
-- The app assigns a PM through public.user_properties: admin_manager_assignments_screen
-- upserts there, and manager_dashboard_screen / property_manager_dashboard_new read
-- their property list from it. properties.company_id is documented in that same screen
-- as an OPTIONAL extra ("Set as primary property manager").
--
-- But the only PM policy on public.properties tested company_id:
--     EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid()
--             AND role = 'property_manager' AND id = company_id)
-- So a PM assigned the normal way (user_properties) got their property ids from
-- user_properties and then read zero rows back from properties. The dashboard renders
-- empty with no error.
--
-- This accepts BOTH mechanisms, matching the admin UI. The helper is SECURITY DEFINER
-- so it does not re-enter the properties/user_properties policies (see 018).

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
            WHERE up.user_id = auth.uid()
              AND up.property_id = prop
       );
$fn$;

DROP POLICY IF EXISTS "Property managers can view assigned properties" ON public.properties;
CREATE POLICY "Property managers can view assigned properties" ON public.properties
    FOR SELECT USING (
        public.pm_has_property(id)
        OR (public.current_user_role() = 'property_manager' AND company_id = auth.uid())
    );
