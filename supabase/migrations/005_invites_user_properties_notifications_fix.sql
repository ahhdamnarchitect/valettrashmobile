-- Relaxed Living Valet ù bridges app + DB gaps (run after 004_rls_policies.sql)
-- Safe to re-run on fresh projects: uses IF NOT EXISTS / DROP IF EXISTS where possible.

-- -----------------------------------------------------------------------------
-- 1) user_properties ù used by manager alerts + notification targeting
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
-- 2) users ù allow new signups to create their own profile row
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
-- 4) notifications ù broadcasts + manager inserts (aligns with Flutter app)
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
-- 5) violations ù optional pickup when reporting from field
-- -----------------------------------------------------------------------------
ALTER TABLE public.violations ALTER COLUMN pickup_id DROP NOT NULL;
