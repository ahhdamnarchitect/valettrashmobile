-- PROVISION PART 5 - wire the demo accounts to the demo property.
-- Run after part4a (auth users) and part4 (profile rows + property/units).
-- Idempotent.

-- Sunset Gardens

-- 1) Property manager -> Sunset Gardens, via user_properties (how the app assigns)
INSERT INTO public.user_properties (user_id, property_id, role)
SELECT u.id, '10000000-0000-0000-0000-000000000001'::uuid, 'manager'
FROM public.users u WHERE u.email = 'adam.grant824+pm@gmail.com'
ON CONFLICT (user_id, property_id) DO NOTHING;

-- 2) Worker -> Sunset Gardens
INSERT INTO public.worker_assignments (user_id, property_id, is_active)
SELECT u.id, '10000000-0000-0000-0000-000000000001'::uuid, true
FROM public.users u WHERE u.email = 'adam.grant824+worker@gmail.com'
ON CONFLICT (user_id, property_id, is_active) DO NOTHING;

-- 3) Residents -> unit 104 at Sunset Gardens
INSERT INTO public.resident_units (user_id, unit_id, property_id, move_in_date, is_active)
SELECT u.id, un.id, '10000000-0000-0000-0000-000000000001'::uuid, CURRENT_DATE - 90, true
FROM public.users u
JOIN public.units un ON un.unit_number = '104'
JOIN public.floors f  ON f.id = un.floor_id
JOIN public.buildings b ON b.id = f.building_id
WHERE u.email = 'adam.grant824+res2@gmail.com'
  AND b.property_id = '10000000-0000-0000-0000-000000000001'::uuid
ON CONFLICT (user_id, unit_id, is_active) DO NOTHING;

-- 4) Owner stays the company owner on both properties (set in part4).

SELECT
  (SELECT count(*) FROM public.user_properties)    AS pm_assignments,
  (SELECT count(*) FROM public.worker_assignments) AS worker_assignments,
  (SELECT count(*) FROM public.resident_units)     AS resident_units;
