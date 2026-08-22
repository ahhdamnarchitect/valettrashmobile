# Project Context

## Purpose
Relaxed Living Valet is a production mobile app for valet trash service at apartment complexes — "Uber for apartments." Residents set bags out; drivers/porters pick them up nightly on timed routes. The app coordinates residents, workers, and property managers with role-based dashboards.

## Tech Stack
- Language: Dart (Flutter mobile), SQL (Supabase migrations)
- Framework: Flutter (cross-platform iOS/Android), Material 3
- Runtime: Flutter SDK ^3.10.9
- Backend: Supabase (PostgreSQL + RLS, Auth, Realtime, Storage)
- Payments: Stripe Checkout (packs + paid comebacks; webhook fulfillment)
- Push Notifications: OneSignal (Phase 2, not yet wired)
- Phase 2 additions: Twilio SMS, Mapbox, Stripe Connect

## User Roles
| Role | DB value | Screen |
|---|---|---|
| Resident | `resident` | ResidentDashboardScreen |
| Driver/Porter | `driver` | WorkerDashboardScreen |
| Property Manager (apartment office) | `property_manager` | PropertyManagerDashboardNewScreen |
| Operations Manager | `operations_manager` | ManagerDashboardScreen |
| Business owner | `owner` or `super_admin` | OwnerDashboardScreen (same); Admin Portal from More |

Test logins: `brain/test_credentials.md`

## Primary Goals
- Residents sign up via invite code + unit number, then track their service
- Drivers see and execute nightly pickup routes; clock in/out; report violations with photos
- Property managers (apartment office) view occupancy, billing, and compliance per property
- Operations managers run nightly ops (routes, workforce timecards, live map)
- Owner views portfolio financials, labor cost, and opens Admin Portal for platform setup

## Constraints
- Single codebase Flutter app — role routing in `AuthGate → RoleHome` at startup
- Supabase keys must live in `mobile/.env` (gitignored)
- All public schema tables need RLS enabled
- Invite code verification routes through SECURITY DEFINER RPCs only — no direct table access
- `invite_codes` table uses `code TEXT` + `unit_id UUID FK` schema (NOT the legacy `invite_code` + `unit_number TEXT` schema)

## Success Criteria
- Resident: download app → enter invite code + unit number → create account → see dashboard
- Driver: log in → see route → mark pickups → file violations with photos
- Property manager: log in → view property pickup + violation history
- All data access gated by RLS policies; no data leaks across roles

## Assumptions / Unknowns
- Stripe Connect contractor payouts not implemented yet; resident Checkout is wired pending secrets
- Marketing site: **https://relaxedlivingvalet.com** (not the Flutter app)
- iOS builds require a Mac; in-person install = TestFlight; Windows demo = Flutter web localhost or LAN IP
- OneSignal push tokens not collected or stored yet
- Admin dashboard (`admin_dashboard/`) is scaffolded but not validated against current DB schema
- `main_simple.dart` exists as a simpler alternate entry point — purpose unclear
