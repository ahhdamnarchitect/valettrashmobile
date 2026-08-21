-- PROVISION PART 2 of 4 - enum values. RUN ALONE, let it commit.
-- Postgres will not let a new enum value be used in the transaction that added
-- it. These are now separate migration files for exactly that reason.
-- Sources: 20260516000005_enum_owner.sql, 20260516000008_enum_operations_manager.sql

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'operations_manager';
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'owner';
