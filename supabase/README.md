# Supabase Database Setup

**Migration order**: see [MIGRATIONS.md](./MIGRATIONS.md) before applying files manually.

This directory contains the complete database schema, RLS policies, and seed data for the Relaxed Living Valet application.

## Database Structure

### Core Tables
- **users** - User profiles and authentication
- **properties** - Apartment complex properties
- **buildings** - Buildings within properties
- **floors** - Floors within buildings
- **units** - Individual apartment units

### Assignment Tables
- **resident_units** - Resident to unit assignments
- **worker_assignments** - Worker to property assignments

### Operations Tables
- **routes** - Driver routes for properties
- **route_stops** - Unit stops within routes
- **nightly_runs** - Daily service runs
- **pickups** - Individual pickup records
- **missed_pickup_requests** - Comeback pickup requests
- **violations** - Violation reports with photos

### Business Logic Tables
- **resident_monthly_usage** - Monthly usage tracking
- **subscriptions** - Resident subscriptions
- **invoices** - Billing invoices

### Communication & Tracking Tables
- **notifications** - Push notifications
- **sms_logs** - SMS message logs
- **audit_logs** - Admin action auditing

### Phase 2 Tables
- **payout_accounts** - Contractor payout accounts
- **contractor_payouts** - Contractor payment records

## Setup Instructions

### 1. Create Supabase Project
1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Note your project URL and anon key

### 2. Run Migrations
Execute the migration files in order:

```bash
# Run initial schema
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f migrations/001_initial_schema.sql

# Run RLS policies
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f migrations/002_rls_policies.sql
```

### 3. Load Seed Data
Execute seed data files in order:

```bash
# Load users
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/001_seed_users.sql

# Load properties
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/002_seed_properties.sql

# Load units
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/003_seed_units.sql

# Load assignments
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/004_seed_assignments.sql

# Load routes
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/005_seed_routes.sql

# Load operations data
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/006_seed_operations.sql

# Load violations and usage
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/007_seed_violations.sql

# Load billing data
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/008_seed_billing.sql

# Load notifications
psql -h your-project.supabase.co -p 5432 -U postgres -d postgres -f seed_data/009_seed_notifications.sql
```

## Test Users

The seed data includes the following test users:

### Super Admin
- **Email**: admin@relaxedlivingvalet.com
- **Password**: (Set via Supabase auth)
- **Role**: super_admin

### Property Managers
- **Email**: manager1@relaxedlivingvalet.com (Sunset Gardens)
- **Email**: manager2@relaxedlivingvalet.com (Oakwood Heights)
- **Role**: property_manager

### Drivers/Porters
- **Email**: driver1@relaxedlivingvalet.com (Sunset Gardens - Building A)
- **Email**: driver2@relaxedlivingvalet.com (Sunset Gardens - Buildings B & C)
- **Email**: driver3@relaxedlivingvalet.com (Oakwood Heights)
- **Role**: driver

### Residents
- **Email**: resident1@relaxedlivingvalet.com (Unit 101)
- **Email**: resident2@relaxedlivingvalet.com (Unit 102)
- **Email**: resident3@relaxedlivingvalet.com (Unit 201)
- **Email**: resident4@relaxedlivingvalet.com (Unit 109)
- **Email**: resident5@relaxedlivingvalet.com (Unit 205)
- **Email**: resident6@relaxedlivingvalet.com (Unit 305)
- **Email**: resident7@relaxedlivingvalet.com (Unit 405)
- **Email**: resident8@relaxedlivingvalet.com (Unit A101)
- **Role**: resident

## Test Properties

### Sunset Gardens Apartments
- **Address**: 1234 Sunset Boulevard, Los Angeles, CA 90028
- **Service Window**: 6:00 PM - 10:00 PM
- **Free Comebacks**: 2 per month
- **Comeback Fee**: $15.00
- **Buildings**: 3 (A, B, C)
- **Total Units**: 20

### Oakwood Heights
- **Address**: 5678 Oak Street, Austin, TX 78701
- **Service Window**: 5:30 PM - 9:30 PM
- **Free Comebacks**: 2 per month
- **Comeback Fee**: $12.00
- **Buildings**: 2 (Building 1, Building 2)
- **Total Units**: 16

## Security Features

### Row Level Security (RLS)
- Residents can only see their own data and property-relevant status
- Workers can only see their assigned routes/properties
- Property managers can only view their own properties
- Super admins can manage everything

### Audit Logging
- All admin actions are logged with before/after values
- IP addresses and user agents are tracked
- Complete audit trail for compliance

## Environment Configuration

Update your Flutter app's `.env` file with:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## Next Steps

1. Set up Supabase Storage buckets for violation photos and user avatars
2. Configure OneSignal for push notifications
3. Set up Stripe for payment processing
4. Deploy Edge Functions for server-side logic

## Support

For issues with the database setup, refer to the migration files or contact the development team.
