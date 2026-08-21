-- Corrective migration for databases that already applied 001_initial_schema.
-- Fresh installs get both fixes from the corrected 001 and do not need this file,
-- though running it is harmless (both statements are idempotent).
--
-- Two defects, both of which made INSERTs impossible on every audited table
-- (properties, buildings, units, resident_units, worker_assignments, violations,
-- subscriptions):
--
--   1. audit_trigger() read NEW.created_by. PL/pgSQL resolves every NEW.<field> at
--      runtime, so referencing a column the table lacks raises
--      `42703: record "new" has no field "created_by"`. COALESCE does not help,
--      and NO audited table has a created_by column.
--
--   2. audit_logs.user_id was NOT NULL, but the actor is NULL for any system
--      -initiated change (seeds, migrations, admin SQL), so the trigger's own
--      insert failed with `23502` and aborted the originating statement.

ALTER TABLE public.audit_logs ALTER COLUMN user_id DROP NOT NULL;

COMMENT ON COLUMN public.audit_logs.user_id IS
    'Actor behind the change; NULL means a system action (seed, migration, admin SQL).';

CREATE OR REPLACE FUNCTION public.audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    rec_new jsonb;
    actor uuid;
BEGIN
    IF TG_OP = 'INSERT' THEN
        rec_new := to_jsonb(NEW);
        actor := COALESCE(
            NULLIF(rec_new->>'created_by', '')::uuid,
            NULLIF(rec_new->>'user_id', '')::uuid,
            NULLIF(rec_new->>'worker_user_id', '')::uuid,
            NULLIF(rec_new->>'resident_user_id', '')::uuid,
            auth.uid()
        );
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, new_values)
        VALUES (actor, 'INSERT', TG_TABLE_NAME, NEW.id, row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values, new_values)
        VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values)
        VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, row_to_json(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
