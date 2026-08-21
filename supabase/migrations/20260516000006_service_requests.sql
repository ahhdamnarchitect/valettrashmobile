-- (enum ALTER moved to 007a_enum_owner.sql; see the note there)
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
