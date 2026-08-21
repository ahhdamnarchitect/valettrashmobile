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
