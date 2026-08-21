-- (enum ALTER moved to 009a_enum_operations_manager.sql; see the note there)
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
