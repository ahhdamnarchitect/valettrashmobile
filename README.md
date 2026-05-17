# Relaxed Living Valet

A production-ready valet trash operations app for apartment complexes that feels like "Uber for apartments."

## Architecture Overview

### Tech Stack
- **Mobile App**: Flutter (cross-platform for iOS/Android)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage, Edge Functions)
- **Payments**: Stripe
- **Push Notifications**: OneSignal
- **Phase 2 Additions**: Twilio SMS, Mapbox, Stripe Connect

### User Roles
1. **Resident** - Requests and monitors trash valet service
2. **Driver/Porter** - Completes nightly pickup routes
3. **Property Manager** - Views reports for their properties
4. **Super Admin** - Manages entire system

### Project Structure
```
relaxed-living-valet/
├── mobile/                     # Flutter mobile app
│   ├── lib/
│   │   ├── core/              # Shared utilities, constants, themes
│   │   ├── data/              # Data layer (repositories, models)
│   │   ├── domain/            # Business logic (use cases, entities)
│   │   ├── presentation/      # UI layer (screens, widgets, navigation)
│   │   └── main.dart
│   ├── assets/
│   └── pubspec.yaml
├── supabase/                   # Supabase configuration
│   ├── migrations/            # Database migrations
│   ├── functions/             # Edge Functions
│   └── seed_data/             # Test data
├── admin_dashboard/            # Web admin dashboard
│   ├── src/
│   │   ├── components/        # Reusable components
│   │   ├── pages/             # Dashboard pages
│   │   ├── services/          # API services
│   │   └── utils/
│   └── package.json
├── docs/                      # Documentation
└── scripts/                   # Development scripts
```

## Phase 1 Features

### Resident App
- Sign up/in and property joining
- Service status and pickup window countdowns
- Push notifications for pickup status
- Missed pickup comeback requests
- Monthly free comeback tracking
- Violation history and billing status

### Driver/Porter App
- Route viewing and progress tracking
- Missed pickup marking
- Violation reporting with photo proof
- Comeback request handling
- Simple field-optimized workflow

### Admin Platform
- Property and unit management
- User role assignments
- Service window configuration
- Violation and pickup review
- Performance analytics
- Billing overview

### Property Manager Dashboard
- Property-specific reporting
- Completion rates and violation tracking
- Exportable reports
- Service activity history

## Phase 2 Features

### Twilio SMS Integration
- Pickup reminders and status updates
- Low balance alerts
- Billing notifications

### Mapbox Integration
- Live route mapping for workers
- Building-level service status
- Privacy-conscious tracking

### Enhanced Manager Dashboard
- Advanced analytics and charts
- Downloadable reports
- Weekly/monthly summaries

### Stripe Connect
- Contractor payout support
- Per-property/door/route compensation
- Payout history and records

## Security & Architecture

- Row Level Security (RLS) for data access control
- Role-based authorization
- Secure file uploads for violation photos
- Environment-based configuration
- Audit logging for admin actions

## Getting Started

See individual README files in each directory for specific setup instructions:

- [Mobile App Setup](./mobile/README.md)
- [Supabase Setup](./supabase/README.md)
- [Admin Dashboard Setup](./admin_dashboard/README.md)

## Development Workflow

3. Apply SQL in order — see **[supabase/MIGRATIONS.md](./supabase/MIGRATIONS.md)** (invites, notifications broadcast, Storage, Stripe webhook notes).
2. Configure environment variables
3. Start Flutter mobile app
4. Start admin dashboard
5. Test with seed data

## Deployment

- Mobile: App Store / Google Play Store
- Backend: Supabase (hosted)
- Admin Dashboard: Vercel / Netlify

## Cursor Repo OS

This repo uses a persistent brain for resumable AI-assisted development.

- Brain files live in `/brain`
- Cursor rules live in `/.cursor/rules`
- Operator docs live in `/cursor-os`
- Bootstrap script lives in `/scripts/init-cursor-os.js`

Future sessions should read and update the brain files before and after meaningful work.

