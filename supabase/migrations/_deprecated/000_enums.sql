-- Relaxed Living Valet - Database Enums
-- This migration creates all custom ENUM types for the valet trash operations system

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create custom ENUM types
CREATE TYPE user_role AS ENUM ('resident', 'driver', 'property_manager', 'super_admin');
CREATE TYPE violation_type AS ENUM ('too_many_bags', 'untied_bags', 'leaking_bags', 'prohibited_items', 'outside_rules');
CREATE TYPE pickup_status AS ENUM ('pending', 'in_progress', 'completed', 'missed', 'comeback_requested');
CREATE TYPE notification_type AS ENUM ('pickup_reminder', 'team_arrived', 'missed_pickup_available', 'violation_reported', 'billing_alert');
CREATE TYPE subscription_status AS ENUM ('active', 'inactive', 'cancelled', 'past_due');
