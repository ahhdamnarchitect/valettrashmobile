-- 026 - stop residents rewriting their own unit assignment and comeback balance.
--
-- 008 added:
--     CREATE POLICY "Residents update own purchased comeback balance"
--         ON public.resident_units FOR UPDATE TO authenticated
--         USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
--
-- That checks WHO owns the row but nothing about WHAT changes, and RLS cannot
-- express per-column rules. Verified against the live API as a resident:
--
--   * PATCH purchased_comeback_balance = 9999  -> 204. Unlimited paid comebacks for
--     free. payment_orders is commented "credits and paid comebacks are applied only
--     by webhook", but the resident could simply set the number themselves, which
--     bypasses Stripe entirely.
--   * PATCH property_id = <the other property> -> 204. The resident relocated
--     themselves, and because resident_has_property() drives the property/building/
--     floor/unit policies, that hands them read access to a property they have no
--     relationship with.
--   * PATCH move_in_date -> 204. Affects billing occupancy.
--
-- RLS still governs row ownership; this trigger enforces the column rules on top.
-- The owner tier and the Stripe webhook (service_role, auth.uid() IS NULL) are exempt,
-- so admin assignment screens and credit top-ups keep working.

CREATE OR REPLACE FUNCTION public.enforce_resident_unit_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- service_role / webhook / admin SQL: no end-user session, nothing to restrict.
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    -- Owner tier manages assignments through the admin screens.
    IF private.is_owner_admin() THEN
        RETURN NEW;
    END IF;

    IF NEW.user_id      IS DISTINCT FROM OLD.user_id
    OR NEW.unit_id      IS DISTINCT FROM OLD.unit_id
    OR NEW.property_id  IS DISTINCT FROM OLD.property_id
    OR NEW.move_in_date IS DISTINCT FROM OLD.move_in_date
    OR NEW.is_active    IS DISTINCT FROM OLD.is_active THEN
        RAISE EXCEPTION 'resident_units: unit assignment is not self-editable';
    END IF;

    -- Spending credits is fine; granting them is not.
    IF NEW.purchased_comeback_balance > OLD.purchased_comeback_balance THEN
        RAISE EXCEPTION 'resident_units: comeback credits are added only by the payment webhook';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_resident_unit_rules ON public.resident_units;
CREATE TRIGGER enforce_resident_unit_rules
    BEFORE UPDATE ON public.resident_units
    FOR EACH ROW EXECUTE FUNCTION public.enforce_resident_unit_rules();

REVOKE ALL ON FUNCTION public.enforce_resident_unit_rules() FROM PUBLIC, anon, authenticated;

-- Repair the rows the audit probes modified.
UPDATE public.resident_units ru
SET property_id = '10000000-0000-0000-0000-000000000001',
    unit_id     = (SELECT u.id FROM public.units u
                   JOIN public.floors f  ON f.id = u.floor_id
                   JOIN public.buildings b ON b.id = f.building_id
                   WHERE u.unit_number = '104'
                     AND b.property_id = '10000000-0000-0000-0000-000000000001'
                   LIMIT 1),
    purchased_comeback_balance = 0,
    move_in_date = CURRENT_DATE - 90,
    updated_at = now()
FROM public.users usr
WHERE usr.id = ru.user_id AND usr.email = 'adam.grant824+res2@gmail.com';
