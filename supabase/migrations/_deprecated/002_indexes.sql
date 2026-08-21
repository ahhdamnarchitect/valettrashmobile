-- Relaxed Living Valet - Database Indexes
-- This migration creates indexes for performance optimization

-- Create indexes for performance
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_properties_company_id ON public.properties(company_id);
CREATE INDEX idx_buildings_property_id ON public.buildings(property_id);
CREATE INDEX idx_floors_building_id ON public.floors(building_id);
CREATE INDEX idx_units_floor_id ON public.units(floor_id);
CREATE INDEX idx_resident_units_user_id ON public.resident_units(user_id);
CREATE INDEX idx_resident_units_property_id ON public.resident_units(property_id);
CREATE INDEX idx_worker_assignments_user_id ON public.worker_assignments(user_id);
CREATE INDEX idx_worker_assignments_property_id ON public.worker_assignments(property_id);
CREATE INDEX idx_routes_property_id ON public.routes(property_id);
CREATE INDEX idx_routes_worker_id ON public.routes(worker_id);
CREATE INDEX idx_route_stops_route_id ON public.route_stops(route_id);
CREATE INDEX idx_nightly_runs_property_id ON public.nightly_runs(property_id);
CREATE INDEX idx_nightly_runs_worker_id ON public.nightly_runs(worker_id);
CREATE INDEX idx_nightly_runs_date ON public.nightly_runs(run_date);
CREATE INDEX idx_pickups_nightly_run_id ON public.pickups(nightly_run_id);
CREATE INDEX idx_pickups_unit_id ON public.pickups(unit_id);
CREATE INDEX idx_pickups_resident_user_id ON public.pickups(resident_user_id);
CREATE INDEX idx_violations_resident_user_id ON public.violations(resident_user_id);
CREATE INDEX idx_violations_unit_id ON public.violations(unit_id);
CREATE INDEX idx_violations_created_at ON public.violations(created_at);
CREATE INDEX idx_resident_monthly_usage_resident_month ON public.resident_monthly_usage(resident_user_id, month);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at);
