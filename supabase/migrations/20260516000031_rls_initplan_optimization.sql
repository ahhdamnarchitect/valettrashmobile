-- 031 - performance: evaluate auth.uid() once per query, not once per row.
--
-- Supabase's Performance Advisor reported 294 "Auth RLS Initialization Plan"
-- warnings. When a policy calls auth.uid() bare, Postgres treats it as volatile per
-- row and re-executes it for every candidate row. Wrapping it in a scalar subquery,
-- `(SELECT auth.uid())`, turns it into an InitPlan evaluated once for the whole
-- statement.
--
-- It is invisible on the demo data (56 units, 1 resident). It is the difference
-- between a fast query and an unusable one at real scale -- a property with 10,000
-- units means 10,000 redundant auth.uid() calls per read, per policy, and there are
-- over 120 policies here.
--
-- Rewriting 100+ policies by hand would be its own bug source, so this rebuilds them
-- programmatically from pg_policies -- the same approach 025 used to move helpers into
-- the private schema. Only the auth.* call sites change; roles, commands, USING and
-- WITH CHECK logic are otherwise reproduced verbatim.

DO $$
DECLARE
    p             record;
    new_qual      text;
    new_check     text;
    cmd_kw        text;
    roles_list    text;
    stmt          text;
    touched       int := 0;
BEGIN
    FOR p IN
        SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
        FROM pg_policies
        WHERE schemaname = 'public'
          AND (
                coalesce(qual, '')       ~ 'auth\.(uid|jwt|role)\(\)'
             OR coalesce(with_check, '') ~ 'auth\.(uid|jwt|role)\(\)'
          )
    LOOP
        -- Wrap only bare calls. A call already inside a subselect is left alone so
        -- this migration stays idempotent.
        new_qual  := regexp_replace(coalesce(p.qual, ''),
                        '(?<!SELECT )auth\.(uid|jwt|role)\(\)', '(SELECT auth.\1())', 'g');
        new_check := regexp_replace(coalesce(p.with_check, ''),
                        '(?<!SELECT )auth\.(uid|jwt|role)\(\)', '(SELECT auth.\1())', 'g');

        IF new_qual = coalesce(p.qual, '') AND new_check = coalesce(p.with_check, '') THEN
            CONTINUE;
        END IF;

        cmd_kw := CASE upper(p.cmd)
                    WHEN 'ALL'    THEN 'ALL'
                    WHEN 'SELECT' THEN 'SELECT'
                    WHEN 'INSERT' THEN 'INSERT'
                    WHEN 'UPDATE' THEN 'UPDATE'
                    WHEN 'DELETE' THEN 'DELETE'
                  END;

        roles_list := array_to_string(ARRAY(SELECT quote_ident(r) FROM unnest(p.roles) AS r), ', ');

        EXECUTE format('DROP POLICY %I ON %I.%I', p.policyname, p.schemaname, p.tablename);

        stmt := format('CREATE POLICY %I ON %I.%I AS %s FOR %s TO %s',
                        p.policyname, p.schemaname, p.tablename,
                        CASE WHEN p.permissive = 'PERMISSIVE' THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END,
                        cmd_kw, roles_list);

        IF nullif(new_qual, '')  IS NOT NULL THEN stmt := stmt || format(' USING (%s)', new_qual); END IF;
        IF nullif(new_check, '') IS NOT NULL THEN stmt := stmt || format(' WITH CHECK (%s)', new_check); END IF;

        EXECUTE stmt;
        touched := touched + 1;
    END LOOP;

    RAISE NOTICE 'rewrote % policies to use InitPlan-style auth calls', touched;
END $$;
