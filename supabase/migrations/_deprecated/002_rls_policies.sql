-- Relaxed Living Valet - Row Level Security Policies
-- This migration creates RLS policies for all tables

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.worker_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.route_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nightly_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pickups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.missed_pickup_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resident_monthly_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contractor_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Users table policies
-- Users can see their own profile
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile (except role)
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id AND role = OLD.role);

-- Super admins can do everything
CREATE POLICY "Super admins can manage all users" ON public.users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Properties table policies
-- Super admins can see all properties
CREATE POLICY "Super admins can view all properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Property managers can see their properties
CREATE POLICY "Property managers can view assigned properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'property_manager' AND id = company_id
        )
    );

-- Workers can see their assigned properties
CREATE POLICY "Workers can view assigned properties" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.worker_assignments 
            WHERE user_id = auth.uid() AND property_id = id AND is_active = true
        )
    );

-- Residents can see their property
CREATE POLICY "Residents can view their property" ON public.properties
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.resident_units 
            WHERE user_id = auth.uid() AND property_id = id AND is_active = true
        )
    );

-- Super admins can manage all properties
CREATE POLICY "Super admins can manage all properties" ON public.properties
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Buildings, Floors, Units policies (follow property access)
CREATE POLICY "Users can view buildings based on property access" ON public.buildings
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all buildings" ON public.buildings
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Users can view floors based on property access" ON public.floors
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buildings b
            JOIN public.properties p ON p.id = b.property_id
            WHERE b.id = building_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all floors" ON public.floors
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Users can view units based on property access" ON public.units
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.floors f
            JOIN public.buildings b ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE f.id = floor_id AND (
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager' AND id = p.company_id)) OR
                (EXISTS (SELECT 1 FROM public.worker_assignments WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true)) OR
                (EXISTS (SELECT 1 FROM public.resident_units WHERE user_id = auth.uid() AND property_id = p.id AND is_active = true))
            )
        )
    );

CREATE POLICY "Super admins can manage all units" ON public.units
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Resident units policies
CREATE POLICY "Residents can view own unit assignments" ON public.resident_units
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Property managers can view resident units for their properties" ON public.resident_units
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all resident units" ON public.resident_units
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Worker assignments policies
CREATE POLICY "Workers can view own assignments" ON public.worker_assignments
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Property managers can view workers for their properties" ON public.worker_assignments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all worker assignments" ON public.worker_assignments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Routes policies
CREATE POLICY "Workers can view own routes" ON public.routes
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Property managers can view routes for their properties" ON public.routes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all routes" ON public.routes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Route stops policies (follow route access)
CREATE POLICY "Users can view route stops based on route access" ON public.route_stops
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.routes r
            WHERE r.id = route_id AND (
                (r.worker_id = auth.uid()) OR
                (EXISTS (SELECT 1 FROM public.properties p WHERE p.id = r.property_id AND p.company_id = auth.uid() AND 
                       EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager'))) OR
                (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin'))
            )
        )
    );

CREATE POLICY "Super admins can manage all route stops" ON public.route_stops
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Nightly runs policies
CREATE POLICY "Workers can view own nightly runs" ON public.nightly_runs
    FOR SELECT USING (worker_id = auth.uid());

CREATE POLICY "Property managers can view runs for their properties" ON public.nightly_runs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Residents can view runs for their property" ON public.nightly_runs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.resident_units 
            WHERE user_id = auth.uid() AND property_id = nightly_runs.property_id AND is_active = true
        )
    );

CREATE POLICY "Super admins can manage all nightly runs" ON public.nightly_runs
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Pickups policies
CREATE POLICY "Residents can view own pickups" ON public.pickups
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view pickups for their runs" ON public.pickups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs 
            WHERE id = nightly_run_id AND worker_id = auth.uid()
        )
    );

CREATE POLICY "Property managers can view pickups for their properties" ON public.pickups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs nr
            JOIN public.properties p ON p.id = nr.property_id
            WHERE nr.id = nightly_run_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Workers can update pickup status" ON public.pickups
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.nightly_runs 
            WHERE id = nightly_run_id AND worker_id = auth.uid()
        )
    );

CREATE POLICY "Super admins can manage all pickups" ON public.pickups
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Missed pickup requests policies
CREATE POLICY "Residents can view own missed pickup requests" ON public.missed_pickup_requests
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view missed pickup requests for their runs" ON public.missed_pickup_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            WHERE p.id = pickup_id AND nr.worker_id = auth.uid()
        )
    );

CREATE POLICY "Property managers can view missed pickups for their properties" ON public.missed_pickup_requests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            JOIN public.properties prop ON prop.id = nr.property_id
            WHERE p.id = pickup_id AND prop.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Residents can create missed pickup requests" ON public.missed_pickup_requests
    FOR INSERT WITH CHECK (resident_user_id = auth.uid());

CREATE POLICY "Workers can update missed pickup request status" ON public.missed_pickup_requests
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.pickups p
            JOIN public.nightly_runs nr ON nr.id = p.nightly_run_id
            WHERE p.id = pickup_id AND nr.worker_id = auth.uid()
        )
    );

CREATE POLICY "Super admins can manage all missed pickup requests" ON public.missed_pickup_requests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Violations policies
CREATE POLICY "Residents can view own violations" ON public.violations
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Workers can view violations they created" ON public.violations
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Property managers can view violations for their properties" ON public.violations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.units u
            JOIN public.floors f ON f.id = u.floor_id
            JOIN public.buildings b ON b.id = f.building_id
            JOIN public.properties p ON p.id = b.property_id
            WHERE u.id = unit_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Workers can create violations" ON public.violations
    FOR INSERT WITH CHECK (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all violations" ON public.violations
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Resident monthly usage policies
CREATE POLICY "Residents can view own monthly usage" ON public.resident_monthly_usage
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view usage for their properties" ON public.resident_monthly_usage
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all monthly usage" ON public.resident_monthly_usage
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Subscriptions policies
CREATE POLICY "Residents can view own subscriptions" ON public.subscriptions
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view subscriptions for their properties" ON public.subscriptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all subscriptions" ON public.subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Invoices policies
CREATE POLICY "Residents can view own invoices" ON public.invoices
    FOR SELECT USING (resident_user_id = auth.uid());

CREATE POLICY "Property managers can view invoices for their properties" ON public.invoices
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.properties p
            WHERE p.id = property_id AND p.company_id = auth.uid() AND 
                  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'property_manager')
        )
    );

CREATE POLICY "Super admins can manage all invoices" ON public.invoices
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can update own notifications" ON public.notifications
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "System can insert notifications" ON public.notifications
    FOR INSERT WITH CHECK (true);

-- Everyone can view audit logs (read-only for transparency)
CREATE POLICY "Authenticated users can view audit logs" ON public.audit_logs
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Payout accounts and contractor payouts (Phase 2)
CREATE POLICY "Workers can view own payout accounts" ON public.payout_accounts
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all payout accounts" ON public.payout_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

CREATE POLICY "Workers can view own payouts" ON public.contractor_payouts
    FOR SELECT USING (worker_user_id = auth.uid());

CREATE POLICY "Super admins can manage all payouts" ON public.contractor_payouts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );

-- SMS logs policies
CREATE POLICY "Users can view own SMS logs" ON public.sms_logs
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Super admins can manage all SMS logs" ON public.sms_logs
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND role = 'super_admin'
        )
    );
