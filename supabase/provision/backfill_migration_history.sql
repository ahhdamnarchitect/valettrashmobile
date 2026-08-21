-- Backfill Supabase's migration history.
--
-- Every migration in this project was applied as raw SQL through the dashboard SQL
-- editor, not through the migration system, so supabase_migrations.schema_migrations
-- does not exist and Supabase believes NOTHING has been applied.
--
-- Connect the GitHub integration in that state and it would try to run all 31
-- migrations against a database that already has every one of them -- failing on
-- "already exists", and potentially half-applying the DROP POLICY / CREATE POLICY
-- pairs, which would leave the authorisation model inconsistent.
--
-- This records them as already applied. It creates no schema objects and changes no
-- data; it only writes history rows. Run it ONCE, before connecting the integration.

CREATE SCHEMA IF NOT EXISTS supabase_migrations;

CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (
    version    text PRIMARY KEY,
    statements text[],
    name       text
);

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES
    ('20260516000001', 'initial_schema'),
    ('20260516000002', 'rls_policies'),
    ('20260516000003', 'invites_user_properties_notifications_fix'),
    ('20260516000004', 'storage_violations'),
    ('20260516000005', 'enum_owner'),
    ('20260516000006', 'service_requests'),
    ('20260516000007', 'resident_comeback_balance_service_time'),
    ('20260516000008', 'enum_operations_manager'),
    ('20260516000009', 'staff_invites'),
    ('20260516000010', 'property_billing_metrics'),
    ('20260516000011', 'property_door_counts'),
    ('20260516000012', 'workforce_labor'),
    ('20260516000013', 'unify_owner_role'),
    ('20260516000014', 'launch_rls_hardening'),
    ('20260516000015', 'stripe_payments'),
    ('20260516000016', 'audit_trigger_system_actions'),
    ('20260516000017', 'fix_users_policy_recursion'),
    ('20260516000018', 'fix_properties_policy_recursion'),
    ('20260516000019', 'fix_violations_policy_performance'),
    ('20260516000020', 'security_audit_logs_and_owner_access'),
    ('20260516000021', 'pm_property_access_via_user_properties'),
    ('20260516000022', 'stop_completions_and_ops_access'),
    ('20260516000023', 'property_hierarchy_access'),
    ('20260516000024', 'function_hardening'),
    ('20260516000025', 'move_rls_helpers_to_private_schema'),
    ('20260516000026', 'resident_units_immutability'),
    ('20260516000027', 'storage_policy_roles'),
    ('20260516000028', 'worker_resident_lookup'),
    ('20260516000029', 'pm_access_via_user_properties'),
    ('20260516000030', 'pm_has_unit_role_guard'),
    ('20260516000031', 'rls_initplan_optimization')
ON CONFLICT (version) DO NOTHING;

SELECT count(*) AS recorded_migrations FROM supabase_migrations.schema_migrations;
