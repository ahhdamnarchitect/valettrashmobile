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
