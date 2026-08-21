-- Relaxed Living Valet - Database Tables
-- This migration creates all tables for the valet trash operations system

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
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
