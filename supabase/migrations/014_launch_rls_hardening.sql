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
