-- PROVISION PART 3 of 5 - policies, features, RLS hardening, security fixes.
-- Run AFTER part 2 has committed.
-- The two ALTER TYPE ... ADD VALUE lines from 007 and 009 are omitted here on
-- purpose; they live in part2_enum_values.sql. Everything else is verbatim.
--
-- 016-025 are corrective/security migrations found while provisioning and
-- auditing on 2026-08-19. They are idempotent, and including them means a fresh
-- database lands exactly on the state verified against the live API:
--   0 Advisor errors, RLS on all 33 tables, 122 policies, no audit-log leak.

-- ============================================================
-- 004_rls_policies.sql
-- ============================================================
-- Relaxed Living Valet - Row Level Security Policies
-- This migration creates RLS policies for all tables

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nightly_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missed_pickup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident_monthly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Users table policies
-- Users can see their own profile
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile (except role).
--
-- FIXED 2026-08-19: this policy previously read
--     FOR UPDATE USING (auth.uid() = id AND role = OLD.role)
-- but OLD is only valid inside a trigger function, never in an RLS policy.
-- Postgres rejects it with `42P01: missing FROM-clause entry for table "old"`,
-- which aborted this entire migration — which is why RLS was never actually
-- enabled on the core tables. The helper below reads the caller's *stored* role
-- via SECURITY DEFINER (so it bypasses RLS and cannot recurse), and the
-- WITH CHECK compares the incoming row against it: you may update your own
-- profile, but you may not change your own role. Same pattern as
-- public.is_owner_admin() in 014_launch_rls_hardening.sql.
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT role FROM public.users WHERE id = auth.uid()
$fn$;

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id AND role = public.current_user_role());

-- Super admins can do everything
-- FIXED 2026-08-19: this policy is ON public.users and its USING clause did
-- `SELECT 1 FROM public.users`, which makes Postgres re-evaluate the same policy
-- to answer itself -> `42P17: infinite recursion detected in policy for relation
-- "users"`. Every anon/authenticated read that touched users returned HTTP 500,
-- including indirectly (a policy on another table that joins users). Routed
-- through the SECURITY DEFINER helper above, which bypasses RLS and cannot recurse.
-- Semantics are unchanged (super_admin only); 014 layers the owner tier on top
-- via public.is_owner_admin().
CREATE POLICY "Super admins can manage all users" ON public.users
    FOR ALL USING (public.current_user_role() = 'super_admin');

-- Properties table policies
-- Super admins can see all properties
CREATE POLICY "Super admins can view all properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Property managers can see their properties
CREATE POLICY "Property managers can view assigned properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'property_manager' AND id = company_id
        )
    );

-- Workers can see their assigned properties
CREATE POLICY "Workers can view assigned properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.worker_assignments 
            WHERE user_id = auth.uid() AND property_id = id AND is_active = true
        )
    );

-- Residents can see their property
CREATE POLICY "Residents can view their property" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.resident_units 
            WHERE user_id = auth.uid() AND property_id = id AND is_active = true
        )
    );

-- Super admins can manage all properties
CREATE POLICY "Super admins can manage all properties" ON public.properties
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Buildings, Floors, Units policies (follow property access)
CREATE POLICY "Users can view buildings based on property access" ON public.buildings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all buildings" ON public.buildings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Users can view floors based on property access" ON public.floors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buildings b
            JOIN public.properties p ON p.id = b.property_id
            WHERE b.id = building_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all floors" ON public.floors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Users can view units based on property access" ON public.units
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.floors f
            JOIN public.buildings b ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE f.id = floor_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all units" ON public.units
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Resident units policies
CREATE POLICY "Residents can view own unit assignments" ON public.resident_units
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Property managers can view resident units for their properties" ON public.resident_units
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all resident units" ON public.resident_units
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Worker assignments policies
CREATE POLICY "Workers can view own assignments" ON public.worker_assignments
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Property managers can view workers for their properties" ON public.worker_assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all worker assignments" ON public.worker_assignments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Routes policies
CREATE POLICY "Workers can view own routes" ON public.routes
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Property managers can view routes for their properties" ON public.routes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all routes" ON public.routes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Route stops policies (follow route access)
CREATE POLICY "Users can view route stops based on route access" ON public.route_stops
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.routes r
            WHERE r.id = route_id AND (
                (r.worker_id = auth.uid()) OR
                (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = r.property_id AND p.company_id = auth.uid() AND 
                       EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager'))) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin'))
            )
        )
    );

CREATE POLICY "Super admins can manage all route stops" ON public.route_stops
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Nightly runs policies
CREATE POLICY "Workers can view own nightly runs" ON public.nightly_runs
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Property managers can view runs for their properties" ON public.nightly_runs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Residents can view runs for their property" ON public.nightly_runs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.resident_units 
            WHERE user_id = auth.uid() AND property_id = nightly_runs.property_id AND is_active = true
        )
    );

CREATE POLICY "Super admins can manage all nightly runs" ON public.nightly_runs
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Pickups policies
CREATE POLICY "Residents can view own pickups" ON public.pickups
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view pickups for their runs" ON public.pickups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs 
            WHERE id = nightly_run_id AND worker_id = auth.uid()
        )
    );

CREATE POLICY "Property managers can view pickups for their properties" ON public.pickups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs nr
            JOIN public.properties p ON p.id = nr.property_id
            WHERE nr.id = nightly_run_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Workers can update pickup status" ON public.pickups
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs 
            WHERE id = nightly_run_id AND worker_id = auth.uid()
        )
    );

CREATE POLICY "Super admins can manage all pickups" ON public.pickups
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Missed pickup requests policies
CREATE POLICY "Residents can view own missed pickup requests" ON public.missed_pickup_requests
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view missed pickup requests for their runs" ON public.missed_pickup_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            WHERE p.id = pickup_id AND nr.worker_id = auth.uid()
        )
    );

CREATE POLICY "Property managers can view missed pickups for their properties" ON public.missed_pickup_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            JOIN public.properties prop ON prop.id = nr.property_id
            WHERE p.id = pickup_id AND prop.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Residents can create missed pickup requests" ON public.missed_pickup_requests
    FOR INSERT WITH CHECK (resident_user_id = auth.uid());

CREATE POLICY "Workers can update missed pickup request status" ON public.missed_pickup_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            WHERE p.id = pickup_id AND nr.worker_id = auth.uid()
        )
    );

CREATE POLICY "Super admins can manage all missed pickup requests" ON public.missed_pickup_requests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Violations policies
CREATE POLICY "Residents can view own violations" ON public.violations
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view violations they created" ON public.violations
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Property managers can view violations for their properties" ON public.violations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.units u
            JOIN public.floors f ON f.id = u.floor_id
            JOIN public.buildings b ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE u.id = unit_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Workers can create violations" ON public.violations
    FOR INSERT WITH CHECK (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all violations" ON public.violations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Resident monthly usage policies
CREATE POLICY "Residents can view own monthly usage" ON public.resident_monthly_usage
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view usage for their properties" ON public.resident_monthly_usage
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all monthly usage" ON public.resident_monthly_usage
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Subscriptions policies
CREATE POLICY "Residents can view own subscriptions" ON public.subscriptions
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view subscriptions for their properties" ON public.subscriptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all subscriptions" ON public.subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Invoices policies
CREATE POLICY "Residents can view own invoices" ON public.invoices
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view invoices for their properties" ON public.invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all invoices" ON public.invoices
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (true);

-- Everyone can view audit logs (read-only for transparency)
CREATE POLICY "Authenticated users can view audit logs" ON public.audit_logs
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Payout accounts and contractor payouts (Phase 2)
CREATE POLICY "Workers can view own payout accounts" ON public.payout_accounts
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all payout accounts" ON public.payout_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Workers can view own payouts" ON public.contractor_payouts
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all payouts" ON public.contractor_payouts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- SMS logs policies
CREATE POLICY "Users can view own SMS logs" ON public.sms_logs
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Super admins can manage all SMS logs" ON public.sms_logs
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- ============================================================
-- 005_invites_user_properties_notifications_fix.sql
-- ============================================================
-- Relaxed Living Valet — bridges app + DB gaps (run after 004_rls_policies.sql)
-- Safe to re-run on fresh projects: uses IF NOT EXISTS / DROP IF EXISTS where possible.

-- -----------------------------------------------------------------------------
-- 1) user_properties — used by manager alerts + notification targeting
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'manager' CHECK (role IN ('manager', 'admin', 'staff')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, property_id)
);

CREATE INDEX IF NOT EXISTS idx_user_properties_user_id ON public.user_properties(user_id);
CREATE INDEX IF NOT EXISTS idx_user_properties_property_id ON public.user_properties(property_id);

ALTER TABLE public.user_properties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users see own user_properties rows" ON public.user_properties;
CREATE POLICY "Users see own user_properties rows" ON public.user_properties
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Super admins manage user_properties" ON public.user_properties;
CREATE POLICY "Super admins manage user_properties" ON public.user_properties
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')
    );

-- -----------------------------------------------------------------------------
-- 2) users — allow new signups to create their own profile row
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id AND role = 'resident');

-- -----------------------------------------------------------------------------
-- 3) invite_codes + verification RPC
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    assigned_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    max_uses INT NOT NULL DEFAULT 1,
    use_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (code, property_id)
);

CREATE INDEX IF NOT EXISTS idx_invite_codes_code ON public.invite_codes(code);

ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone authenticated can read invite codes for verify" ON public.invite_codes;
-- Verification uses SECURITY DEFINER function; keep table locked down
CREATE POLICY "No direct invite_codes access" ON public.invite_codes
    FOR SELECT USING (false);

DROP POLICY IF EXISTS "Super admins manage invite_codes" ON public.invite_codes;
CREATE POLICY "Super admins manage invite_codes" ON public.invite_codes
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')
    );

CREATE OR REPLACE FUNCTION public.verify_invite_code(
    p_invite_code TEXT,
    p_property_id UUID,
    p_unit_number TEXT
)
RETURNS TABLE (
    is_valid BOOLEAN,
    invite_id UUID,
    unit_id UUID,
    property_id UUID,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv public.invite_codes%ROWTYPE;
    v_unit_number TEXT;
BEGIN
    IF p_invite_code IS NULL OR trim(p_invite_code) = '' THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::UUID, 'Missing code';
        RETURN;
    END IF;

    SELECT u.unit_number INTO v_unit_number
    FROM public.units u
    JOIN public.floors fl ON fl.id = u.floor_id
    JOIN public.buildings b ON b.id = fl.building_id
    WHERE b.property_id = p_property_id AND u.unit_number = trim(p_unit_number)
    LIMIT 1;

    IF v_unit_number IS NULL THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::UUID, 'Unknown unit for property';
        RETURN;
    END IF;

    SELECT ic.* INTO v_inv
    FROM public.invite_codes ic
    WHERE ic.code = trim(p_invite_code)
      AND ic.property_id = p_property_id
      AND ic.unit_id IN (
          SELECT u.id FROM public.units u
          JOIN public.floors fl ON fl.id = u.floor_id
          JOIN public.buildings b ON b.id = fl.building_id
          WHERE b.property_id = p_property_id AND u.unit_number = trim(p_unit_number)
      )
    ORDER BY ic.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::UUID, 'Invite not found';
        RETURN;
    END IF;

    IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < NOW() THEN
        RETURN QUERY SELECT false, v_inv.id, v_inv.unit_id, v_inv.property_id, 'Invite expired';
        RETURN;
    END IF;

    IF v_inv.assigned_user_id IS NOT NULL OR v_inv.use_count >= v_inv.max_uses THEN
        RETURN QUERY SELECT false, v_inv.id, v_inv.unit_id, v_inv.property_id, 'Invite already used';
        RETURN;
    END IF;

    RETURN QUERY SELECT true, v_inv.id, v_inv.unit_id, v_inv.property_id, 'OK';
END;
$$;

REVOKE ALL ON FUNCTION public.verify_invite_code(TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_invite_code(TEXT, UUID, TEXT) TO anon, authenticated;

-- Claim invite after successful auth signup (clients cannot UPDATE invite_codes under RLS)
CREATE OR REPLACE FUNCTION public.claim_invite_code(p_invite_id UUID, p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'User mismatch';
    END IF;

    UPDATE public.invite_codes
    SET assigned_user_id = p_user_id,
        assigned_at = NOW(),
        use_count = use_count + 1
    WHERE id = p_invite_id
      AND assigned_user_id IS NULL
      AND use_count < max_uses;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_invite_code(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_invite_code(UUID, UUID) TO authenticated;

-- Allow a newly registered resident to attach to the unit tied to their claimed invite.
DROP POLICY IF EXISTS "Residents self-register assignment matching claimed invite"
    ON public.resident_units;

CREATE POLICY "Residents self-register assignment matching claimed invite"
    ON public.resident_units
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.invite_codes ic
            WHERE ic.assigned_user_id = auth.uid()
              AND ic.unit_id = resident_units.unit_id
              AND ic.property_id = resident_units.property_id
        )
    );

-- -----------------------------------------------------------------------------
-- 4) notifications — broadcasts + manager inserts (aligns with Flutter app)
-- -----------------------------------------------------------------------------
ALTER TABLE public.notifications ALTER COLUMN user_id DROP NOT NULL;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::JSONB;

CREATE INDEX IF NOT EXISTS idx_notifications_property_created
    ON public.notifications(property_id, created_at DESC);

DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
CREATE POLICY "Residents see targeted or property notifications" ON public.notifications
    FOR SELECT USING (
        auth.role() = 'authenticated' AND (
            user_id = auth.uid()
            OR (
                user_id IS NULL
                AND property_id IS NOT NULL
                AND EXISTS (
                    SELECT 1 FROM public.resident_units ru
                    WHERE ru.user_id = auth.uid()
                      AND ru.property_id = notifications.property_id
                      AND ru.is_active = true
                )
            )
        )
    );

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;

CREATE POLICY "Managers and admins insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated' AND (
            EXISTS (
                SELECT 1 FROM public.users u
                WHERE u.id = auth.uid() AND u.role IN ('property_manager', 'super_admin')
            )
            OR EXISTS (
                SELECT 1 FROM public.user_properties up
                WHERE up.user_id = auth.uid() AND up.role IN ('manager', 'admin')
            )
        )
    );

-- -----------------------------------------------------------------------------
-- 5) violations — optional pickup when reporting from field
-- -----------------------------------------------------------------------------
ALTER TABLE public.violations ALTER COLUMN pickup_id DROP NOT NULL;

-- ============================================================
-- 006_storage_violations.sql
-- ============================================================
-- Storage bucket for violation / support photos (private; access via RLS policies)

DROP POLICY IF EXISTS "Users upload own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Users read own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Users update own violation files" ON storage.objects;
DROP POLICY IF EXISTS "Workers upload violation photos" ON storage.objects;
DROP POLICY IF EXISTS "Workers read own uploads" ON storage.objects;

INSERT INTO storage.buckets (id, name, public)
VALUES ('violations', 'violations', false)
ON CONFLICT (id) DO NOTHING;

-- Residents: read/write own folder users/<uid>/...
CREATE POLICY "Users upload own violation files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users read own violation files"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

CREATE POLICY "Users update own violation files"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

-- Drivers can use workers/<uid>/...
CREATE POLICY "Workers upload violation photos"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'workers'
    AND (storage.foldername(name))[2] = auth.uid()::text
    AND EXISTS (
        SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('driver', 'property_manager', 'super_admin')
    )
);

CREATE POLICY "Workers read own uploads"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'violations'
    AND (storage.foldername(name))[1] = 'workers'
    AND (storage.foldername(name))[2] = auth.uid()::text
);

-- ============================================================
-- 007_service_requests.sql
-- ============================================================
-- Extra / add-on service requests from residents (Moving, Maid, Bulk, etc.)
-- Required before policies reference role 'owner' (Flutter OwnerDashboardScreen).

CREATE TABLE IF NOT EXISTS public.service_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
    service_type TEXT NOT NULL,
    preferred_date DATE,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_review', 'fulfilled', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_requests_status
    ON public.service_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_requests_resident
    ON public.service_requests(resident_user_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_created
    ON public.service_requests(created_at DESC);

ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;

-- Residents: insert own, read own
CREATE POLICY "Residents insert own service requests"
    ON public.service_requests FOR INSERT TO authenticated
    WITH CHECK (resident_user_id = auth.uid());

CREATE POLICY "Residents view own service requests"
    ON public.service_requests FOR SELECT TO authenticated
    USING (resident_user_id = auth.uid());

-- Owner + super_admin: view and update all
CREATE POLICY "Owner and super_admin view service requests"
    ON public.service_requests FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('owner', 'super_admin')
        )
    );

CREATE POLICY "Owner and super_admin update service requests"
    ON public.service_requests FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('owner', 'super_admin')
        )
    );

-- ============================================================
-- 008_resident_comeback_balance_service_time.sql
-- ============================================================
-- Purchased comeback credits roll over; free monthly comeback tracked in resident_monthly_usage.
-- Service requests: optional preferred time of day.

ALTER TABLE public.resident_units
    ADD COLUMN IF NOT EXISTS purchased_comeback_balance INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.service_requests
    ADD COLUMN IF NOT EXISTS preferred_time TIME;

-- Residents may spend banked purchased credits (increment on purchase).
CREATE POLICY "Residents update own purchased comeback balance"
    ON public.resident_units FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 009_staff_invites.sql
-- ============================================================
-- Staff invite codes for property managers, operations managers, and drivers.
-- Residents continue to use invite_codes + unit flow.


CREATE TABLE IF NOT EXISTS public.staff_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL,
    target_role TEXT NOT NULL CHECK (
        target_role IN ('property_manager', 'operations_manager', 'driver')
    ),
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    max_uses INT NOT NULL DEFAULT 1,
    use_count INT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    claimed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    claimed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (code)
);

CREATE INDEX IF NOT EXISTS idx_staff_invites_code ON public.staff_invites(code);
CREATE INDEX IF NOT EXISTS idx_staff_invites_property ON public.staff_invites(property_id);

ALTER TABLE public.staff_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "No direct staff_invites access"
    ON public.staff_invites FOR SELECT USING (false);

CREATE POLICY "Super admins manage staff_invites"
    ON public.staff_invites FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE OR REPLACE FUNCTION public.verify_staff_invite_code(p_invite_code TEXT)
RETURNS TABLE (
    is_valid BOOLEAN,
    invite_id UUID,
    property_id UUID,
    property_name TEXT,
    target_role TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv public.staff_invites%ROWTYPE;
    v_prop_name TEXT;
BEGIN
    IF p_invite_code IS NULL OR trim(p_invite_code) = '' THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT, NULL::TEXT, 'Enter an invite code';
        RETURN;
    END IF;

    SELECT si.* INTO v_inv
    FROM public.staff_invites si
    WHERE upper(trim(si.code)) = upper(trim(p_invite_code))
    ORDER BY si.created_at DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT, NULL::TEXT, 'Invalid staff invite code';
        RETURN;
    END IF;

    IF NOT v_inv.is_active THEN
        RETURN QUERY SELECT false, v_inv.id, v_inv.property_id, NULL::TEXT, v_inv.target_role, 'Invite revoked';
        RETURN;
    END IF;

    IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < NOW() THEN
        RETURN QUERY SELECT false, v_inv.id, v_inv.property_id, NULL::TEXT, v_inv.target_role, 'Invite expired';
        RETURN;
    END IF;

    IF v_inv.use_count >= v_inv.max_uses THEN
        RETURN QUERY SELECT false, v_inv.id, v_inv.property_id, NULL::TEXT, v_inv.target_role, 'Invite already used';
        RETURN;
    END IF;

    SELECT p.name INTO v_prop_name FROM public.properties p WHERE p.id = v_inv.property_id;

    RETURN QUERY SELECT true, v_inv.id, v_inv.property_id, v_prop_name, v_inv.target_role, 'OK';
END;
$$;

REVOKE ALL ON FUNCTION public.verify_staff_invite_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_staff_invite_code(TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.register_staff_with_invite(
    p_invite_id UUID,
    p_user_id UUID,
    p_email TEXT,
    p_first_name TEXT,
    p_last_name TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv public.staff_invites%ROWTYPE;
    v_role public.user_role;
BEGIN
    IF auth.uid() IS DISTINCT FROM p_user_id THEN
        RAISE EXCEPTION 'User mismatch';
    END IF;

    SELECT * INTO v_inv FROM public.staff_invites WHERE id = p_invite_id FOR UPDATE;

    IF NOT FOUND OR NOT v_inv.is_active THEN
        RAISE EXCEPTION 'Invalid invite';
    END IF;

    IF v_inv.expires_at IS NOT NULL AND v_inv.expires_at < NOW() THEN
        RAISE EXCEPTION 'Invite expired';
    END IF;

    IF v_inv.use_count >= v_inv.max_uses THEN
        RAISE EXCEPTION 'Invite already used';
    END IF;

    v_role := v_inv.target_role::public.user_role;

    INSERT INTO public.users (id, email, first_name, last_name, role, is_active)
    VALUES (
        p_user_id,
        trim(p_email),
        trim(p_first_name),
        trim(p_last_name),
        v_role,
        true
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        role = EXCLUDED.role,
        is_active = true;

    INSERT INTO public.user_properties (user_id, property_id, role)
    VALUES (p_user_id, v_inv.property_id, 'manager')
    ON CONFLICT (user_id, property_id) DO NOTHING;

    IF v_inv.target_role = 'property_manager' THEN
        UPDATE public.properties
        SET company_id = p_user_id
        WHERE id = v_inv.property_id;
    ELSIF v_inv.target_role = 'driver' THEN
        IF EXISTS (
            SELECT 1 FROM public.worker_assignments
            WHERE user_id = p_user_id AND property_id = v_inv.property_id
        ) THEN
            UPDATE public.worker_assignments
            SET is_active = true
            WHERE user_id = p_user_id AND property_id = v_inv.property_id;
        ELSE
            INSERT INTO public.worker_assignments (user_id, property_id, is_active)
            VALUES (p_user_id, v_inv.property_id, true);
        END IF;
    END IF;

    UPDATE public.staff_invites
    SET use_count = use_count + 1,
        claimed_by = p_user_id,
        claimed_at = NOW()
    WHERE id = p_invite_id;
END;
$$;

REVOKE ALL ON FUNCTION public.register_staff_with_invite(UUID, UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_staff_with_invite(UUID, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ============================================================
-- 010_property_billing_metrics.sql
-- ============================================================
-- Per-property contract billing: fee per door + 85% minimum billable occupancy.

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS monthly_fee_per_door DECIMAL(10, 2) NOT NULL DEFAULT 25.00;

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS minimum_billable_occupancy_percent DECIMAL(5, 4) NOT NULL DEFAULT 0.8500;

COMMENT ON COLUMN public.properties.monthly_fee_per_door IS
    'Monthly amount billed per billable door (property manager contract).';

COMMENT ON COLUMN public.properties.minimum_billable_occupancy_percent IS
    'Minimum share of total units billed even if fewer residents are active (e.g. 0.85 = 85%).';

-- ============================================================
-- 011_property_door_counts.sql
-- ============================================================
-- Manual door counts for billing (when unit tree not fully built in app).

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS billing_total_doors INTEGER;

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS billing_occupied_doors INTEGER;

COMMENT ON COLUMN public.properties.billing_total_doors IS
    'Total doors/units for contract billing; falls back to counted units when null.';

COMMENT ON COLUMN public.properties.billing_occupied_doors IS
    'Occupied doors for billing; falls back to active resident_units when null.';

-- ============================================================
-- 012_workforce_labor.sql
-- ============================================================
-- Workforce: hourly rates, clock events, live locations (idempotent).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS hourly_rate DECIMAL(10, 2) DEFAULT 18.00;

COMMENT ON COLUMN public.users.hourly_rate IS
  'Default hourly pay for drivers; used for owner labor estimates.';

CREATE TABLE IF NOT EXISTS public.clock_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('clock_in', 'clock_out')),
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clock_events_user_created
  ON public.clock_events(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clock_events_property_created
  ON public.clock_events(property_id, created_at DESC);

ALTER TABLE public.clock_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workers_own_clock_events" ON public.clock_events;
CREATE POLICY "workers_own_clock_events" ON public.clock_events
  FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "managers_read_clock_events" ON public.clock_events;
CREATE POLICY "managers_read_clock_events" ON public.clock_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN (
          'operations_manager',
          'property_manager',
          'owner',
          'super_admin'
        )
    )
  );

CREATE TABLE IF NOT EXISTS public.worker_locations (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.worker_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workers_own_location" ON public.worker_locations;
CREATE POLICY "workers_own_location" ON public.worker_locations
  FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "managers_read_locations" ON public.worker_locations;
CREATE POLICY "managers_read_locations" ON public.worker_locations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid()
        AND u.role IN (
          'operations_manager',
          'property_manager',
          'owner',
          'super_admin'
        )
    )
  );

-- Owner / super_admin: set driver hourly rate.
CREATE OR REPLACE FUNCTION public.set_worker_hourly_rate(
  p_worker_id UUID,
  p_rate NUMERIC
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_rate IS NULL OR p_rate < 0 THEN
    RAISE EXCEPTION 'invalid hourly rate';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('owner', 'super_admin')
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.users
  SET hourly_rate = p_rate, updated_at = now()
  WHERE id = p_worker_id AND role = 'driver';
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_worker_hourly_rate(UUID, NUMERIC)
  TO authenticated;

-- ============================================================
-- 013_unify_owner_role.sql
-- ============================================================
-- Business owner: `owner` and `super_admin` are the same tier (app routes both to Owner dashboard).
-- Canonical role for the primary login is `owner`.

UPDATE public.users
SET role = 'owner', updated_at = now()
WHERE email = 'relaxedlivingtx@gmail.com'
  AND role = 'super_admin';

-- Optional dedicated owner test alias (create matching auth user in Supabase Auth first).
UPDATE public.users
SET role = 'owner', updated_at = now()
WHERE email = 'relaxedlivingtx+owner@gmail.com';

COMMENT ON TYPE public.user_role IS
  'owner and super_admin both map to Owner dashboard; prefer owner for new accounts.';

-- ============================================================
-- 014_launch_rls_hardening.sql
-- ============================================================
-- Launch readiness: re-enable RLS, owner-admin helpers, policies for satellite tables.
-- Apply AFTER 012 and 013. Run supabase/tests/rls_role_smoke.sql after applying.

-- ---------------------------------------------------------------------------
-- Role helpers (SECURITY DEFINER — read public.users safely inside policies)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_owner_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role IN ('owner', 'super_admin')
  );
$$;

CREATE OR REPLACE FUNCTION public.is_staff_role(target text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role::text = target
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_owner_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff_role(text) TO authenticated;

-- ---------------------------------------------------------------------------
-- Re-enable RLS on core tables (hosted DB had RLS disabled on many)
-- ---------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.resident_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.worker_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.nightly_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pickups ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.missed_pickup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.resident_monthly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.contractor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.staff_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.clock_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.worker_locations ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- Owner tier: parallel policies (OR with existing super_admin policies)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "Owners can manage all users" ON public.users;
CREATE POLICY "Owners can manage all users" ON public.users
  FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Owners can manage all properties" ON public.properties;
CREATE POLICY "Owners can manage all properties" ON public.properties
  FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Owners can view all properties" ON public.properties;
CREATE POLICY "Owners can view all properties" ON public.properties
  FOR SELECT USING (public.is_owner_admin());

DROP POLICY IF EXISTS "Owners can manage contractor payouts" ON public.contractor_payouts;
CREATE POLICY "Owners can manage contractor payouts" ON public.contractor_payouts
  FOR ALL USING (public.is_owner_admin());

-- ---------------------------------------------------------------------------
-- user_properties (PM/OM property scope)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_properties (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
  role TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, property_id)
);

ALTER TABLE public.user_properties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own user_properties" ON public.user_properties;
CREATE POLICY "Users view own user_properties" ON public.user_properties
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Owner admin manage user_properties" ON public.user_properties;
CREATE POLICY "Owner admin manage user_properties" ON public.user_properties
  FOR ALL USING (public.is_owner_admin());

-- ---------------------------------------------------------------------------
-- invite_codes
-- ---------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.invite_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Owner admin manage invite codes" ON public.invite_codes;
CREATE POLICY "Owner admin manage invite codes" ON public.invite_codes
  FOR ALL USING (public.is_owner_admin());

DROP POLICY IF EXISTS "PM view property invite codes" ON public.invite_codes;
CREATE POLICY "PM view property invite codes" ON public.invite_codes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.user_properties up
      WHERE up.user_id = auth.uid()
        AND up.property_id = invite_codes.property_id
    )
    AND public.is_staff_role('property_manager')
  );

-- ---------------------------------------------------------------------------
-- resident_concerns
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.resident_concerns (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  subject TEXT,
  message TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'resolved')),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.resident_concerns ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Residents insert own concerns" ON public.resident_concerns;
CREATE POLICY "Residents insert own concerns" ON public.resident_concerns
  FOR INSERT WITH CHECK (resident_user_id = auth.uid());

DROP POLICY IF EXISTS "Residents view own concerns" ON public.resident_concerns;
CREATE POLICY "Residents view own concerns" ON public.resident_concerns
  FOR SELECT USING (resident_user_id = auth.uid());

DROP POLICY IF EXISTS "Owner admin manage concerns" ON public.resident_concerns;
CREATE POLICY "Owner admin manage concerns" ON public.resident_concerns
  FOR ALL USING (public.is_owner_admin());

-- ---------------------------------------------------------------------------
-- community_announcements, direct_messages, satisfaction_ratings
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.community_announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES public.properties(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  sent_by UUID REFERENCES public.users(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.community_announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read community announcements" ON public.community_announcements;
CREATE POLICY "Read community announcements" ON public.community_announcements
  FOR SELECT USING (
    property_id IN (
      SELECT property_id FROM public.resident_units
      WHERE user_id = auth.uid() AND is_active = true
    )
    OR property_id IN (
      SELECT property_id FROM public.user_properties WHERE user_id = auth.uid()
    )
    OR public.is_owner_admin()
    OR public.is_staff_role('operations_manager')
    OR public.is_staff_role('property_manager')
  );

DROP POLICY IF EXISTS "Staff insert community announcements" ON public.community_announcements;
CREATE POLICY "Staff insert community announcements" ON public.community_announcements
  FOR INSERT WITH CHECK (
    public.is_owner_admin()
    OR public.is_staff_role('property_manager')
    OR public.is_staff_role('operations_manager')
  );

CREATE TABLE IF NOT EXISTS public.direct_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own direct messages" ON public.direct_messages;
CREATE POLICY "Users read own direct messages" ON public.direct_messages
  FOR SELECT USING (sender_id = auth.uid() OR recipient_id = auth.uid());

DROP POLICY IF EXISTS "Users send direct messages" ON public.direct_messages;
CREATE POLICY "Users send direct messages" ON public.direct_messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "Recipients mark messages read" ON public.direct_messages;
CREATE POLICY "Recipients mark messages read" ON public.direct_messages
  FOR UPDATE USING (recipient_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.satisfaction_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id),
  run_id UUID REFERENCES public.nightly_runs(id),
  rating INT CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.satisfaction_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Residents insert satisfaction ratings" ON public.satisfaction_ratings;
CREATE POLICY "Residents insert satisfaction ratings" ON public.satisfaction_ratings
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Read satisfaction ratings" ON public.satisfaction_ratings;
CREATE POLICY "Read satisfaction ratings" ON public.satisfaction_ratings
  FOR SELECT USING (
    user_id = auth.uid()
    OR public.is_owner_admin()
    OR public.is_staff_role('property_manager')
    OR public.is_staff_role('operations_manager')
  );

-- ============================================================
-- 015_stripe_payments.sql
-- ============================================================
-- Stripe Checkout for comeback packs and paid single comebacks.

ALTER TABLE public.missed_pickup_requests
  ALTER COLUMN pickup_id DROP NOT NULL;

ALTER TABLE public.missed_pickup_requests
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS payment_amount_cents INTEGER,
  ADD COLUMN IF NOT EXISTS stripe_checkout_session_id TEXT,
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_missed_pickup_stripe_session
  ON public.missed_pickup_requests (stripe_checkout_session_id)
  WHERE stripe_checkout_session_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.payment_orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  property_id UUID REFERENCES public.properties(id) ON DELETE SET NULL,
  resident_unit_id UUID REFERENCES public.resident_units(id) ON DELETE SET NULL,
  missed_pickup_request_id UUID REFERENCES public.missed_pickup_requests(id) ON DELETE SET NULL,
  kind TEXT NOT NULL CHECK (kind IN ('pack', 'comeback')),
  quantity INTEGER NOT NULL DEFAULT 1,
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'usd',
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'paid', 'canceled', 'failed')),
  stripe_checkout_session_id TEXT UNIQUE,
  stripe_payment_intent_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_payment_orders_user
  ON public.payment_orders (user_id, created_at DESC);

ALTER TABLE public.payment_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Residents view own payment orders" ON public.payment_orders;
CREATE POLICY "Residents view own payment orders" ON public.payment_orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Owner admin view payment orders" ON public.payment_orders;
CREATE POLICY "Owner admin view payment orders" ON public.payment_orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('owner', 'super_admin')
    )
  );

COMMENT ON TABLE public.payment_orders IS
  'Stripe Checkout orders. Credits and paid comebacks are applied only by webhook.';

-- ============================================================
-- 016_audit_trigger_system_actions.sql
-- ============================================================
-- Corrective migration for databases that already applied 001_initial_schema.
-- Fresh installs get both fixes from the corrected 001 and do not need this file,
-- though running it is harmless (both statements are idempotent).
--
-- Two defects, both of which made INSERTs impossible on every audited table
-- (properties, buildings, units, resident_units, worker_assignments, violations,
-- subscriptions):
--
--   1. audit_trigger() read NEW.created_by. PL/pgSQL resolves every NEW.<field> at
--      runtime, so referencing a column the table lacks raises
--      `42703: record "new" has no field "created_by"`. COALESCE does not help,
--      and NO audited table has a created_by column.
--
--   2. audit_logs.user_id was NOT NULL, but the actor is NULL for any system
--      -initiated change (seeds, migrations, admin SQL), so the trigger's own
--      insert failed with `23502` and aborted the originating statement.

ALTER TABLE public.audit_logs ALTER COLUMN user_id DROP NOT NULL;

COMMENT ON COLUMN public.audit_logs.user_id IS
    'Actor behind the change; NULL means a system action (seed, migration, admin SQL).';

CREATE OR REPLACE FUNCTION public.audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    rec_new jsonb;
    actor uuid;
BEGIN
    IF TG_OP = 'INSERT' THEN
        rec_new := to_jsonb(NEW);
        actor := COALESCE(
            NULLIF(rec_new->>'created_by', '')::uuid,
            NULLIF(rec_new->>'user_id', '')::uuid,
            NULLIF(rec_new->>'worker_user_id', '')::uuid,
            NULLIF(rec_new->>'resident_user_id', '')::uuid,
            auth.uid()
        );
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, new_values)
        VALUES (actor, 'INSERT', TG_TABLE_NAME, NEW.id, row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values, new_values)
        VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values)
        VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 017_fix_users_policy_recursion.sql
-- ============================================================
-- Corrective migration for databases that already applied 004_rls_policies.
-- Fresh installs get this from the corrected 004; re-running here is harmless.
--
-- `Super admins can manage all users` is a policy ON public.users whose USING
-- clause selected FROM public.users. Postgres must evaluate the policy to answer
-- the subquery, which re-enters the same policy:
--     42P17: infinite recursion detected in policy for relation "users"
-- Any read touching public.users returned HTTP 500 — directly, or indirectly via
-- a policy on another table that joins users. That is effectively the whole app.
--
-- public.current_user_role() is SECURITY DEFINER, so its read of public.users
-- bypasses RLS and cannot recurse. Same for public.is_owner_admin() in 014.

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $fn$
    SELECT role FROM public.users WHERE id = auth.uid()
$fn$;

DROP POLICY IF EXISTS "Super admins can manage all users" ON public.users;
CREATE POLICY "Super admins can manage all users" ON public.users
    FOR ALL USING (public.current_user_role() = 'super_admin');

-- ============================================================
-- 018_fix_properties_policy_recursion.sql
-- ============================================================
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

-- ============================================================
-- 019_fix_violations_policy_performance.sql
-- ============================================================
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

-- ============================================================
-- 020_security_audit_logs_and_owner_access.sql
-- ============================================================
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

-- ============================================================
-- 021_pm_property_access_via_user_properties.sql
-- ============================================================
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

-- ============================================================
-- 022_stop_completions_and_ops_access.sql
-- ============================================================
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

-- ============================================================
-- 023_property_hierarchy_access.sql
-- ============================================================
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

-- ============================================================
-- 024_function_hardening.sql
-- ============================================================
-- 024 - function hardening (Supabase Security Advisor).
--
-- 1. search_path. audit_trigger() is SECURITY DEFINER with no `SET search_path`.
--    That is a genuine escalation vector: whoever triggers the function controls
--    search_path, so an attacker-created `users` table earlier on the path could be
--    written to with the definer's privileges. handle_updated_at() is not SECURITY
--    DEFINER, but pinning it costs nothing and clears the linter.
--
-- 2. EXECUTE grants. The advisor flags every SECURITY DEFINER function as callable.
--    For the RLS helpers that is unavoidable and harmless - a policy can only be
--    evaluated if the querying role may execute the functions it calls, and each
--    returns just a boolean/NULL about the CALLER (verified: anon gets
--    is_owner_admin() = false, current_user_role() = NULL, no data disclosed).
--    For the rest, anon has no business calling them at all, so EXECUTE is revoked.

-- ---------------------------------------------------------------------------
-- 1. Pin search_path on the two flagged functions
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.audit_trigger()     SET search_path = public, pg_temp;
ALTER FUNCTION public.handle_updated_at() SET search_path = public, pg_temp;

-- ---------------------------------------------------------------------------
-- 2. Trigger functions must never be callable through the API
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.audit_trigger()     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_updated_at() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Privileged / signup RPCs: signed-in callers only, never anon.
--    Each authorizes internally as well (defence in depth) - set_worker_hourly_rate
--    raises 'not authorized' unless the caller is owner/super_admin, and the invite
--    functions are called immediately after signUp(), so a session always exists.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.set_worker_hourly_rate(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_worker_hourly_rate(uuid, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.claim_invite_code(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_invite_code(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.register_staff_with_invite(uuid, uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_staff_with_invite(uuid, uuid, text, text, text) TO authenticated;

-- verify_* are read-only code lookups used before a session exists on the signup
-- screens, so anon keeps EXECUTE. They return only whether a code is valid.

-- ============================================================
-- 025_move_rls_helpers_to_private_schema.sql
-- ============================================================
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

