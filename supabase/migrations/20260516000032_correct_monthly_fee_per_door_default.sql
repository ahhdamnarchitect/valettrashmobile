-- Correct the per-door contract rate default: 25.00 -> 18.00.
--
-- WHY: 25.00 was never a rate we sell. It conflated the RESIDENT-facing fee with
-- the rate the PROPERTY pays us. The real model, confirmed with the owner on
-- 2026-08-21, is:
--
--     property pays Relaxed Living Valet  $15-18 / door / month
--     property bills its own residents    $25-35 / door / month
--     property keeps the spread  <- this is why a property manager says yes
--
-- Left at 25.00, every new property row would be quoted at roughly the resident
-- price, which is ~$7-10/door above what we actually sell and wipes out the
-- property's margin entirely. See `brain/sales/offer.md`.
--
-- 18.00 is the month-to-month rate (the entry offer). The 36-month rate is 15.00
-- and is set per property, not by this default.

ALTER TABLE public.properties
    ALTER COLUMN monthly_fee_per_door SET DEFAULT 18.00;

-- Re-point rows still carrying the old default. Any row at exactly 25.00 got that
-- value from the previous column default rather than from a real negotiated rate --
-- there are no signed properties yet, so nothing here overwrites a real contract.
-- Deliberately scoped to = 25.00 so a deliberately-set rate is never clobbered.
UPDATE public.properties
   SET monthly_fee_per_door = 18.00
 WHERE monthly_fee_per_door = 25.00;

COMMENT ON COLUMN public.properties.monthly_fee_per_door IS
    'Monthly amount the PROPERTY pays us per billable door (not the resident-facing '
    'fee -- the property bills residents separately and keeps the spread). '
    'Default 18.00 = month-to-month rate; 15.00 on a 36-month term. See brain/sales/offer.md.';
