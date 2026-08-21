-- PROVISION PART 1 of 4 - baseline schema
-- Run first, alone. Creates enums, tables, indexes, triggers.
-- Source: migrations/20260516000001_initial_schema.sql

-- Relaxed Living Valet - Initial Database Schema
-- This migration creates all tables for the valet trash operations system

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom ENUM types
CREATE TYPE user_role AS ENUM ('resident', 'driver', 'property_manager', 'super_admin');
CREATE TYPE violation_type AS ENUM ('too_many_bags', 'untied_bags', 'leaking_bags', 'prohibited_items', 'outside_rules');
CREATE TYPE pickup_status AS ENUM ('pending', 'in_progress', 'completed', 'missed', 'comeback_requested');
CREATE TYPE notification_type AS ENUM ('pickup_reminder', 'team_arrived', 'missed_pickup_available', 'violation_reported', 'billing_alert');
CREATE TYPE subscription_status AS ENUM ('active', 'inactive', 'cancelled', 'past_due');

-- Users table - extends Supabase auth.users
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    phone TEXT,
    role user_role NOT NULL DEFAULT 'resident',
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Properties table
CREATE TABLE public.properties (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    zip_code TEXT NOT NULL,
    company_id UUID REFERENCES public.users(id), -- Super admin company owner
    service_window_start TIME NOT NULL DEFAULT '18:00:00',
    service_window_end TIME NOT NULL DEFAULT '22:00:00',
    free_comeback_pickups_per_month INTEGER DEFAULT 3,
    comeback_pickup_fee DECIMAL(10,2) DEFAULT 15.00,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Buildings table
CREATE TABLE public.buildings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    floors INTEGER NOT NULL DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Floors table
CREATE TABLE public.floors (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE,
    floor_number INTEGER NOT NULL,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Units table
CREATE TABLE public.units (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    floor_id UUID NOT NULL REFERENCES public.floors(id) ON DELETE CASCADE,
    unit_number TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(floor_id, unit_number)
);

-- Resident assignments to units
CREATE TABLE public.resident_units (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    move_in_date DATE NOT NULL,
    move_out_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, unit_id, is_active)
);

-- Worker assignments to properties
CREATE TABLE public.worker_assignments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    is_active BOOLEAN DEFAULT true,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, property_id, is_active)
);

-- Routes for workers
CREATE TABLE public.routes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Route stops (specific units in order)
CREATE TABLE public.route_stops (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(route_id, unit_id)
);

-- Nightly service runs
CREATE TABLE public.nightly_runs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    run_date DATE NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    total_units INTEGER NOT NULL DEFAULT 0,
    completed_units INTEGER NOT NULL DEFAULT 0,
    missed_units INTEGER NOT NULL DEFAULT 0,
    violations_count INTEGER NOT NULL DEFAULT 0,
    status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(property_id, run_date)
);

-- Individual pickups
CREATE TABLE public.pickups (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    nightly_run_id UUID NOT NULL REFERENCES public.nightly_runs(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status pickup_status NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(nightly_run_id, unit_id)
);

-- Missed pickup comeback requests
CREATE TABLE public.missed_pickup_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pickup_id UUID NOT NULL REFERENCES public.pickups(id) ON DELETE CASCADE,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    is_free BOOLEAN DEFAULT true,
    fee_amount DECIMAL(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'completed', 'expired')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Violations
CREATE TABLE public.violations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pickup_id UUID NOT NULL REFERENCES public.pickups(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES public.units(id) ON DELETE CASCADE,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    worker_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    violation_type violation_type NOT NULL,
    description TEXT,
    photo_url TEXT,
    is_warning BOOLEAN DEFAULT true,
    fee_amount DECIMAL(10,2) DEFAULT 0.00,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'disputed', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Resident monthly usage tracking
CREATE TABLE public.resident_monthly_usage (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    month DATE NOT NULL, -- First day of the month
    free_comeback_used INTEGER NOT NULL DEFAULT 0,
    paid_comeback_used INTEGER NOT NULL DEFAULT 0,
    violations_count INTEGER NOT NULL DEFAULT 0,
    total_fees DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(resident_user_id, property_id, month)
);

-- Subscriptions
CREATE TABLE public.subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    stripe_subscription_id TEXT UNIQUE,
    status subscription_status NOT NULL DEFAULT 'active',
    monthly_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(resident_user_id, property_id)
);

-- Invoices
CREATE TABLE public.invoices (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    resident_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    stripe_invoice_id TEXT UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    due_date DATE NOT NULL,
    paid_at TIMESTAMP WITH TIME ZONE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Notifications
CREATE TABLE public.notifications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    data JSONB, -- Additional notification data
    is_read BOOLEAN DEFAULT false,
    push_sent BOOLEAN DEFAULT false,
    sms_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- SMS logs (for Phase 2)
CREATE TABLE public.sms_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    phone TEXT NOT NULL,
    message TEXT NOT NULL,
    twilio_sid TEXT UNIQUE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
    sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contractor payout accounts (for Phase 2)
CREATE TABLE public.payout_accounts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    worker_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    stripe_account_id TEXT UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Contractor payouts (for Phase 2)
CREATE TABLE public.contractor_payouts (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    worker_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    nightly_run_id UUID REFERENCES public.nightly_runs(id) ON DELETE SET NULL,
    amount DECIMAL(10,2) NOT NULL,
    payout_type TEXT NOT NULL CHECK (payout_type IN ('per_property', 'per_door', 'per_route', 'bonus')),
    description TEXT,
    stripe_payout_id TEXT UNIQUE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'failed')),
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit logs for admin actions
CREATE TABLE public.audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    -- FIXED 2026-08-19: was NOT NULL. audit_trigger() derives the actor from
    -- auth.uid(), which is NULL for system-initiated changes (seed scripts,
    -- migrations, admin SQL in the dashboard). With NOT NULL, the trigger's own
    -- insert failed with 23502 and took the originating statement down with it —
    -- meaning no row could be inserted into any audited table except by a
    -- logged-in app user. NULL here means "system action".
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER handle_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_properties_updated_at BEFORE UPDATE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_buildings_updated_at BEFORE UPDATE ON public.buildings FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_floors_updated_at BEFORE UPDATE ON public.floors FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_units_updated_at BEFORE UPDATE ON public.units FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_resident_units_updated_at BEFORE UPDATE ON public.resident_units FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_worker_assignments_updated_at BEFORE UPDATE ON public.worker_assignments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_routes_updated_at BEFORE UPDATE ON public.routes FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_pickups_updated_at BEFORE UPDATE ON public.pickups FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_resident_monthly_usage_updated_at BEFORE UPDATE ON public.resident_monthly_usage FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_subscriptions_updated_at BEFORE UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_payout_accounts_updated_at BEFORE UPDATE ON public.payout_accounts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Create audit trigger function
CREATE OR REPLACE FUNCTION public.audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    -- FIXED 2026-08-19: the INSERT branch previously read
    --     COALESCE(NEW.created_by, NEW.user_id, NEW.worker_user_id, NEW.resident_user_id, auth.uid())
    -- PL/pgSQL resolves every NEW.<field> at runtime, so referencing a column the
    -- table does not have raises `42703: record "new" has no field "created_by"` —
    -- COALESCE does not protect against it. NO audited table has created_by, so this
    -- broke EVERY insert into properties, buildings, units, resident_units,
    -- worker_assignments, violations and subscriptions.
    -- Going through to_jsonb() yields NULL for absent keys instead of erroring,
    -- preserving the original precedence.
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
        VALUES (
            actor,
            'INSERT',
            TG_TABLE_NAME,
            NEW.id,
            row_to_json(NEW)
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values, new_values)
        VALUES (
            COALESCE(auth.uid()),
            'UPDATE',
            TG_TABLE_NAME,
            NEW.id,
            row_to_json(OLD),
            row_to_json(NEW)
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (user_id, action, table_name, record_id, old_values)
        VALUES (
            COALESCE(auth.uid()),
            'DELETE',
            TG_TABLE_NAME,
            OLD.id,
            row_to_json(OLD)
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add audit triggers to key tables
CREATE TRIGGER audit_properties AFTER INSERT OR UPDATE OR DELETE ON public.properties FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_buildings AFTER INSERT OR UPDATE OR DELETE ON public.buildings FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_units AFTER INSERT OR UPDATE OR DELETE ON public.units FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_resident_units AFTER INSERT OR UPDATE OR DELETE ON public.resident_units FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_worker_assignments AFTER INSERT OR UPDATE OR DELETE ON public.worker_assignments FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_violations AFTER INSERT OR UPDATE OR DELETE ON public.violations FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
CREATE TRIGGER audit_subscriptions AFTER INSERT OR UPDATE OR DELETE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.audit_trigger();
