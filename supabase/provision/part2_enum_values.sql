-- PROVISION PART 2 of 3 — enum values. RUN THIS ALONE, then wait for it to finish.
--
-- WHY SEPARATE: Postgres refuses to use a new enum value in the same transaction
-- that added it ("unsafe use of new value ... of enum type"). The Supabase SQL
-- editor runs each execution as a single transaction, so these two statements
-- must commit BEFORE part 3 references 'owner' / 'operations_manager' in policies
-- and CHECK constraints.
--
-- Sources: migrations/007_service_requests.sql, migrations/009_staff_invites.sql

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'owner';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'operations_manager';
