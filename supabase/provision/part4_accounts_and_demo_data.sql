-- PROVISION PART 4 of 4 — test accounts + minimal demo data
-- Run AFTER part 3.
--
-- ─────────────────────────────────────────────────────────────────────────
-- STEP 4a — CREATE THE AUTH USERS FIRST (Dashboard, not SQL)
-- ─────────────────────────────────────────────────────────────────────────
-- public.users.id is a FOREIGN KEY to auth.users(id), so a profile row cannot
-- exist before its auth user. In the Supabase Dashboard:
--   Authentication → Users → Add user → Create new user
--   ✅ tick "Auto Confirm User" (email confirmation is disabled for this app)
--
-- Create these seven, with the passwords from brain/test_credentials.md:
--   relaxedlivingtx@gmail.com              → owner (primary business owner)
--   relaxedlivingtx+owner@gmail.com        → owner (optional alias)
--   adam.grant824+om@gmail.com             → operations_manager
--   adam.grant824+worker@gmail.com         → driver
--   adam.grant824+pm@gmail.com             → property_manager
--   adam.grant824+res2@gmail.com           → resident
--   adam.grant824+testres104@gmail.com     → resident
--
-- Do NOT run supabase/seed_data/001_seed_users.sql. It inserts hardcoded UUIDs
-- (00000000-…-0001 etc.) that have no matching auth.users row, so every insert
-- fails the foreign key. Seeds 004–009 depend on those same fake UUIDs and will
-- fail for the same reason. This file replaces 001 and 002.
--
-- ─────────────────────────────────────────────────────────────────────────
-- STEP 4b — profile rows, keyed to the REAL auth UUIDs by email lookup
-- ─────────────────────────────────────────────────────────────────────────

INSERT INTO public.users (id, email, first_name, last_name, phone, role, is_active)
SELECT au.id, au.email, v.first_name, v.last_name, v.phone, v.role::public.user_role, true
FROM (VALUES
    ('relaxedlivingtx@gmail.com',          'Relaxed', 'Living',  NULL,          'owner'),
    ('relaxedlivingtx+owner@gmail.com',    'Owner',   'Alias',   NULL,          'owner'),
    ('adam.grant824+om@gmail.com',         'Ops',     'Manager', '+1-555-0002', 'operations_manager'),
    ('adam.grant824+worker@gmail.com',     'Test',    'Worker',  '+1-555-0003', 'driver'),
    ('adam.grant824+pm@gmail.com',         'Property','Manager', '+1-555-0004', 'property_manager'),
    ('adam.grant824+res2@gmail.com',       'Test',    'Resident','+1-555-0005', 'resident'),
    ('adam.grant824+testres104@gmail.com', 'Unit104', 'Resident','+1-555-0006', 'resident')
) AS v(email, first_name, last_name, phone, role)
JOIN auth.users au ON au.email = v.email
ON CONFLICT (id) DO UPDATE
    SET role = EXCLUDED.role,
        first_name = EXCLUDED.first_name,
        last_name  = EXCLUDED.last_name,
        is_active  = true,
        updated_at = NOW();

-- Verify: expect 7 rows. Any missing = that auth user was not created in 4a.
SELECT u.email, u.role FROM public.users u ORDER BY u.role::text, u.email;

-- ─────────────────────────────────────────────────────────────────────────
-- STEP 4c — properties (company_id nulled; resolved by email below)
-- Source: seed_data/002_seed_properties.sql, fabricated user UUIDs removed
-- ─────────────────────────────────────────────────────────────────────────

-- Seed Properties Data
-- This file creates test properties with buildings, floors, and units

-- Properties
INSERT INTO public.properties (
    id,
    name,
    address,
    city,
    state,
    zip_code,
    company_id,
    service_window_start,
    service_window_end,
    free_comeback_pickups_per_month,
    comeback_pickup_fee,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '10000000-0000-0000-0000-000000000001',
    'Sunset Gardens Apartments',
    '1234 Sunset Boulevard',
    'Los Angeles',
    'CA',
    '90028',
    NULL,
    '18:00:00',
    '22:00:00',
    3,
    15.00,
    true,
    NOW(),
    NOW()
),
(
    '10000000-0000-0000-0000-000000000002',
    'Oakwood Heights',
    '5678 Oak Street',
    'Austin',
    'TX',
    '78701',
    NULL,
    '17:30:00',
    '21:30:00',
    2,
    12.00,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Buildings for Sunset Gardens
INSERT INTO public.buildings (
    id,
    property_id,
    name,
    floors,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'Building A',
    3,
    1,
    NOW(),
    NOW()
),
(
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    'Building B',
    4,
    2,
    NOW(),
    NOW()
),
(
    '20000000-0000-0000-0000-000000000003',
    '10000000-0000-0000-0000-000000000001',
    'Building C',
    3,
    3,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Buildings for Oakwood Heights
INSERT INTO public.buildings (
    id,
    property_id,
    name,
    floors,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '20000000-0000-0000-0000-000000000004',
    '10000000-0000-0000-0000-000000000002',
    'Building 1',
    2,
    1,
    NOW(),
    NOW()
),
(
    '20000000-0000-0000-0000-000000000005',
    '10000000-0000-0000-0000-000000000002',
    'Building 2',
    2,
    2,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Floors for Sunset Gardens Building A
INSERT INTO public.floors (
    id,
    building_id,
    floor_number,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '30000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000001',
    1,
    1,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000001',
    2,
    2,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000003',
    '20000000-0000-0000-0000-000000000001',
    3,
    3,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Floors for Sunset Gardens Building B
INSERT INTO public.floors (
    id,
    building_id,
    floor_number,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '30000000-0000-0000-0000-000000000004',
    '20000000-0000-0000-0000-000000000002',
    1,
    1,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000005',
    '20000000-0000-0000-0000-000000000002',
    2,
    2,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000006',
    '20000000-0000-0000-0000-000000000002',
    3,
    3,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000007',
    '20000000-0000-0000-0000-000000000002',
    4,
    4,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Floors for Sunset Gardens Building C
INSERT INTO public.floors (
    id,
    building_id,
    floor_number,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '30000000-0000-0000-0000-000000000008',
    '20000000-0000-0000-0000-000000000003',
    1,
    1,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000009',
    '20000000-0000-0000-0000-000000000003',
    2,
    2,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000010',
    '20000000-0000-0000-0000-000000000003',
    3,
    3,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Floors for Oakwood Heights Building 1
INSERT INTO public.floors (
    id,
    building_id,
    floor_number,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '30000000-0000-0000-0000-000000000011',
    '20000000-0000-0000-0000-000000000004',
    1,
    1,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000012',
    '20000000-0000-0000-0000-000000000004',
    2,
    2,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Floors for Oakwood Heights Building 2
INSERT INTO public.floors (
    id,
    building_id,
    floor_number,
    sort_order,
    created_at,
    updated_at
) VALUES 
(
    '30000000-0000-0000-0000-000000000013',
    '20000000-0000-0000-0000-000000000005',
    1,
    1,
    NOW(),
    NOW()
),
(
    '30000000-0000-0000-0000-000000000014',
    '20000000-0000-0000-0000-000000000005',
    2,
    2,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Point both properties at the real business owner.
UPDATE public.properties
SET company_id = (SELECT id FROM public.users WHERE email = 'relaxedlivingtx@gmail.com')
WHERE company_id IS NULL;

-- ─────────────────────────────────────────────────────────────────────────
-- STEP 4d — units (no user references; safe verbatim)
-- Source: seed_data/003_seed_units.sql
-- ─────────────────────────────────────────────────────────────────────────

-- Seed Units Data
-- This file creates test units for all floors

-- Units for Sunset Gardens Building A - Floor 1
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    '101',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    '102',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000001',
    '103',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000001',
    '104',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building A - Floor 2
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000005',
    '30000000-0000-0000-0000-000000000002',
    '201',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000006',
    '30000000-0000-0000-0000-000000000002',
    '202',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000007',
    '30000000-0000-0000-0000-000000000002',
    '203',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000008',
    '30000000-0000-0000-0000-000000000002',
    '204',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building A - Floor 3
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000009',
    '30000000-0000-0000-0000-000000000003',
    '301',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000010',
    '30000000-0000-0000-0000-000000000003',
    '302',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000011',
    '30000000-0000-0000-0000-000000000003',
    '303',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000012',
    '30000000-0000-0000-0000-000000000003',
    '304',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building B - Floor 1
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000013',
    '30000000-0000-0000-0000-000000000004',
    '105',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000014',
    '30000000-0000-0000-0000-000000000004',
    '106',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000015',
    '30000000-0000-0000-0000-000000000004',
    '107',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000016',
    '30000000-0000-0000-0000-000000000004',
    '108',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building B - Floor 2
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000017',
    '30000000-0000-0000-0000-000000000005',
    '205',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000018',
    '30000000-0000-0000-0000-000000000005',
    '206',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000019',
    '30000000-0000-0000-0000-000000000005',
    '207',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000020',
    '30000000-0000-0000-0000-000000000005',
    '208',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building B - Floor 3
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000021',
    '30000000-0000-0000-0000-000000000006',
    '305',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000022',
    '30000000-0000-0000-0000-000000000006',
    '306',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000023',
    '30000000-0000-0000-0000-000000000006',
    '307',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000024',
    '30000000-0000-0000-0000-000000000006',
    '308',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building B - Floor 4
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000025',
    '30000000-0000-0000-0000-000000000007',
    '405',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000026',
    '30000000-0000-0000-0000-000000000007',
    '406',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000027',
    '30000000-0000-0000-0000-000000000007',
    '407',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000028',
    '30000000-0000-0000-0000-000000000007',
    '408',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building C - Floor 1
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000029',
    '30000000-0000-0000-0000-000000000008',
    '109',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000030',
    '30000000-0000-0000-0000-000000000008',
    '110',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000031',
    '30000000-0000-0000-0000-000000000008',
    '111',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000032',
    '30000000-0000-0000-0000-000000000008',
    '112',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building C - Floor 2
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000033',
    '30000000-0000-0000-0000-000000000009',
    '209',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000034',
    '30000000-0000-0000-0000-000000000009',
    '210',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000035',
    '30000000-0000-0000-0000-000000000009',
    '211',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000036',
    '30000000-0000-0000-0000-000000000009',
    '212',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Sunset Gardens Building C - Floor 3
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000037',
    '30000000-0000-0000-0000-000000000010',
    '309',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000038',
    '30000000-0000-0000-0000-000000000010',
    '310',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000039',
    '30000000-0000-0000-0000-000000000010',
    '311',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000040',
    '30000000-0000-0000-0000-000000000010',
    '312',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Oakwood Heights Building 1 - Floor 1
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000041',
    '30000000-0000-0000-0000-000000000011',
    'A101',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000042',
    '30000000-0000-0000-0000-000000000011',
    'A102',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000043',
    '30000000-0000-0000-0000-000000000011',
    'A103',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000044',
    '30000000-0000-0000-0000-000000000011',
    'A104',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Oakwood Heights Building 1 - Floor 2
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000045',
    '30000000-0000-0000-0000-000000000012',
    'A201',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000046',
    '30000000-0000-0000-0000-000000000012',
    'A202',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000047',
    '30000000-0000-0000-0000-000000000012',
    'A203',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000048',
    '30000000-0000-0000-0000-000000000012',
    'A204',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Oakwood Heights Building 2 - Floor 1
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000049',
    '30000000-0000-0000-0000-000000000013',
    'B101',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000050',
    '30000000-0000-0000-0000-000000000013',
    'B102',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000051',
    '30000000-0000-0000-0000-000000000013',
    'B103',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000052',
    '30000000-0000-0000-0000-000000000013',
    'B104',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- Units for Oakwood Heights Building 2 - Floor 2
INSERT INTO public.units (
    id,
    floor_id,
    unit_number,
    sort_order,
    is_active,
    created_at,
    updated_at
) VALUES 
(
    '40000000-0000-0000-0000-000000000053',
    '30000000-0000-0000-0000-000000000014',
    'B201',
    1,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000054',
    '30000000-0000-0000-0000-000000000014',
    'B202',
    2,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000055',
    '30000000-0000-0000-0000-000000000014',
    'B203',
    3,
    true,
    NOW(),
    NOW()
),
(
    '40000000-0000-0000-0000-000000000056',
    '30000000-0000-0000-0000-000000000014',
    'B204',
    4,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────
-- STEP 4e — invite code WELCOME104 (Sunset Gardens unit 104)
-- Source: seed_data/010_seed_invite_codes.sql
-- ─────────────────────────────────────────────────────────────────────────

-- Sample invite for testing invite-based resident signup (Sunset Gardens property, unit 104)
-- Run after 003_seed_units.sql. Code: WELCOME104

INSERT INTO public.invite_codes (
    code,
    property_id,
    unit_id,
    max_uses,
    use_count,
    expires_at
)
VALUES (
    'WELCOME104',
    '10000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000004',
    10,
    0,
    NOW() + INTERVAL '365 days'
)
ON CONFLICT (code, property_id) DO NOTHING;
