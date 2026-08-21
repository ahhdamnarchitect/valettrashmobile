-- PROVISION PART 4a - demo auth users.
-- Run BEFORE part4_accounts_and_demo_data.sql, which keys public.users rows to
-- these auth UUIDs by email.
--
-- These are DEMO credentials for a development project; they are already recorded
-- in brain/test_credentials.md. Do not use this pattern for real accounts - use
-- Supabase Auth (dashboard, or the admin API) so password policy, rate limiting
-- and audit trails apply.
--
-- Idempotent: re-running skips emails that already exist.

DO $$
DECLARE
    u        record;
    new_id   uuid;
    n_made   int := 0;
BEGIN
    FOR u IN
        SELECT * FROM (VALUES
            ('relaxedlivingtx@gmail.com',          'RelaxedLiving2026!'),
            ('relaxedlivingtx+owner@gmail.com',    'RelaxedLiving2026!'),
            ('adam.grant824+om@gmail.com',         'TestPass123!'),
            ('adam.grant824+worker@gmail.com',     'TestPass123!'),
            ('adam.grant824+pm@gmail.com',         'TestPass123!'),
            ('adam.grant824+res2@gmail.com',       'TestPass123!'),
            ('adam.grant824+testres104@gmail.com', 'TestPass123!')
        ) AS t(email, pw)
    LOOP
        IF EXISTS (SELECT 1 FROM auth.users au WHERE au.email = u.email) THEN
            CONTINUE;
        END IF;

        new_id := gen_random_uuid();

        INSERT INTO auth.users (
            instance_id, id, aud, role, email, encrypted_password,
            email_confirmed_at, created_at, updated_at,
            raw_app_meta_data, raw_user_meta_data,
            confirmation_token, recovery_token, email_change, email_change_token_new
        ) VALUES (
            '00000000-0000-0000-0000-000000000000',
            new_id, 'authenticated', 'authenticated',
            u.email,
            extensions.crypt(u.pw, extensions.gen_salt('bf')),
            now(), now(), now(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{}'::jsonb,
            '', '', '', ''
        );

        -- GoTrue v2 requires a matching identity row for email/password sign-in.
        INSERT INTO auth.identities (
            user_id, provider_id, identity_data, provider,
            last_sign_in_at, created_at, updated_at
        ) VALUES (
            new_id, new_id::text,
            jsonb_build_object(
                'sub', new_id::text,
                'email', u.email,
                'email_verified', true,
                'phone_verified', false
            ),
            'email', now(), now(), now()
        );

        n_made := n_made + 1;
    END LOOP;

    RAISE NOTICE 'created % auth users', n_made;
END $$;

SELECT email, (email_confirmed_at IS NOT NULL) AS confirmed
FROM auth.users ORDER BY email;
