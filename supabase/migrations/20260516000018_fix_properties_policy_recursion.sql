-- Corrective migration: breaks the two mutual-recursion cycles in the RLS graph.
--
--     properties -> resident_units    -> properties
--     properties -> worker_assignments -> properties
--
-- "Residents can view their property" (on properties) selects FROM resident_units,
-- while "Property managers can view resident units..." (on resident_units) selects
-- FROM properties. Evaluating either policy requires evaluating the other, so
-- Postgres aborts with `42P17: infinite recursion detected in policy for relation
-- "properties"`. Same shape for worker_assignments. Every REST read of properties,
-- units, floors, buildings and worker_assignments returned HTTP 500.
--
-- Both cycles pass through the two policies ON public.properties, so routing just
-- those through SECURITY DEFINER helpers (which bypass RLS and cannot re-enter the
-- policy system) breaks both. Access semantics are unchanged.

CREATE OR REPLACE FUNCTION public.resident_has_property(prop uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT EXISTS (
        SELECT 1 FROM public.resident_units
        WHERE user_id = auth.uid() AND property_id = prop AND is_active = true
    );
$fn$;

CREATE OR REPLACE FUNCTION public.worker_has_property(prop uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT EXISTS (
        SELECT 1 FROM public.worker_assignments
        WHERE user_id = auth.uid() AND property_id = prop AND is_active = true
    );
$fn$;

DROP POLICY IF EXISTS "Residents can view their property" ON public.properties;
CREATE POLICY "Residents can view their property" ON public.properties
    FOR SELECT USING (public.resident_has_property(id));

DROP POLICY IF EXISTS "Workers can view assigned properties" ON public.properties;
CREATE POLICY "Workers can view assigned properties" ON public.properties
    FOR SELECT USING (public.worker_has_property(id));
