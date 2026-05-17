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
