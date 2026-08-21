-- Adds the 'operations_manager' value to public.user_role.
--
-- Split out of 009_staff_invites.sql deliberately. Postgres will not let a new enum value be
-- USED in the same transaction that added it, and the GitHub integration runs
-- each migration file as one transaction -- so the ALTER has to land and commit
-- in a file of its own before the next migration can reference it.

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'operations_manager';
