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
