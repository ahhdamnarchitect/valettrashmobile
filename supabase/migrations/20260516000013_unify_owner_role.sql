-- Business owner: `owner` and `super_admin` are the same tier (app routes both to Owner dashboard).
-- Canonical role for the primary login is `owner`.

UPDATE public.users
SET role = 'owner', updated_at = now()
WHERE email = 'relaxedlivingtx@gmail.com'
  AND role = 'super_admin';

-- Optional dedicated owner test alias (create matching auth user in Supabase Auth first).
UPDATE public.users
SET role = 'owner', updated_at = now()
WHERE email = 'relaxedlivingtx+owner@gmail.com';

COMMENT ON TYPE public.user_role IS
  'owner and super_admin both map to Owner dashboard; prefer owner for new accounts.';
