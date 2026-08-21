-- 020 — security fix + owner-tier access.
--
-- TWO PROBLEMS, both found by probing the live API as a real logged-in user.
--
-- 1. SECURITY (confirmed exploitable): audit_logs was readable by ANY authenticated
--    user —
--        CREATE POLICY "Authenticated users can view audit logs" ON public.audit_logs
--            FOR SELECT USING (auth.uid() IS NOT NULL);
--    audit_logs stores row_to_json() snapshots of every insert/update/delete on
--    properties, buildings, units, resident_units, worker_assignments, violations and
--    subscriptions. A resident test account read all 67 rows, including full property
--    records with billing rates and per-door fees, and would equally see other
--    residents' unit assignments and violation history. Now restricted to the owner tier.
--
-- 2. ACCESS: 013_unify_owner_role made `owner` the canonical role for the business
--    owner, but 22 admin policies still tested `role = 'super_admin'` only, and 014
--    added owner-tier policies to just 3 tables. Net effect: the owner logged in and
--    saw 0 units, 0 buildings, 0 routes, 0 pickups, 0 invoices — their own business was
--    invisible. Each is widened to public.is_owner_admin(), which covers BOTH owner and
--    super_admin, so no access is lost and the recursive/expensive
--    `EXISTS (SELECT 1 FROM public.users ...)` subquery is dropped at the same time.

-- ---------------------------------------------------------------------------
-- 1. audit_logs — owner tier only
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users can view audit logs" ON public.audit_logs;

CREATE POLICY "Owner admins can view audit logs" ON public.audit_logs
    FOR SELECT USING (public.is_owner_admin());

COMMENT ON TABLE public.audit_logs IS
    'Change history incl. full row snapshots. Owner-tier read only: it exposes every audited table.';

-- ---------------------------------------------------------------------------
-- 2. Admin-tier policies: super_admin -> owner + super_admin
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Super admins can manage all buildings" ON public.buildings;
CREATE POLICY "Super admins can manage all buildings" ON public.buildings
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all payouts" ON public.contractor_payouts;
CREATE POLICY "Super admins can manage all payouts" ON public.contractor_payouts
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all floors" ON public.floors;
CREATE POLICY "Super admins can manage all floors" ON public.floors
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all invoices" ON public.invoices;
CREATE POLICY "Super admins can manage all invoices" ON public.invoices
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all missed pickup requests" ON public.missed_pickup_requests;
CREATE POLICY "Super admins can manage all missed pickup requests" ON public.missed_pickup_requests
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all nightly runs" ON public.nightly_runs;
CREATE POLICY "Super admins can manage all nightly runs" ON public.nightly_runs
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all payout accounts" ON public.payout_accounts;
CREATE POLICY "Super admins can manage all payout accounts" ON public.payout_accounts
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all pickups" ON public.pickups;
CREATE POLICY "Super admins can manage all pickups" ON public.pickups
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all properties" ON public.properties;
CREATE POLICY "Super admins can manage all properties" ON public.properties
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can view all properties" ON public.properties;
CREATE POLICY "Super admins can view all properties" ON public.properties
    FOR SELECT USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all monthly usage" ON public.resident_monthly_usage;
CREATE POLICY "Super admins can manage all monthly usage" ON public.resident_monthly_usage
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all resident units" ON public.resident_units;
CREATE POLICY "Super admins can manage all resident units" ON public.resident_units
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all route stops" ON public.route_stops;
CREATE POLICY "Super admins can manage all route stops" ON public.route_stops
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all routes" ON public.routes;
CREATE POLICY "Super admins can manage all routes" ON public.routes
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all SMS logs" ON public.sms_logs;
CREATE POLICY "Super admins can manage all SMS logs" ON public.sms_logs
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all subscriptions" ON public.subscriptions;
CREATE POLICY "Super admins can manage all subscriptions" ON public.subscriptions
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all units" ON public.units;
CREATE POLICY "Super admins can manage all units" ON public.units
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all violations" ON public.violations;
CREATE POLICY "Super admins can manage all violations" ON public.violations
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins can manage all worker assignments" ON public.worker_assignments;
CREATE POLICY "Super admins can manage all worker assignments" ON public.worker_assignments
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins manage invite_codes" ON public.invite_codes;
CREATE POLICY "Super admins manage invite_codes" ON public.invite_codes
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins manage user_properties" ON public.user_properties;
CREATE POLICY "Super admins manage user_properties" ON public.user_properties
    FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Super admins manage staff_invites" ON public.staff_invites;
CREATE POLICY "Super admins manage staff_invites" ON public.staff_invites
    FOR ALL USING (public.is_owner_admin());


-- ---------------------------------------------------------------------------
-- 3. notifications — let the owner tier and ops managers send, not just PM/super_admin
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "Managers and admins insert notifications" ON public.notifications;
CREATE POLICY "Managers and admins insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (
        public.is_owner_admin()
        OR public.current_user_role() IN ('property_manager', 'operations_manager')
    );
