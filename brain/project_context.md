# Project Context

## Purpose
Relaxed Living Valet is a production mobile app for valet trash service at apartment complexes — "Uber for apartments." Residents set bags out; drivers/porters pick them up nightly on timed routes. The app coordinates residents, workers, and property managers with role-based dashboards.

## Tech Stack
- Language: Dart (Flutter mobile), SQL (Supabase migrations)
- Framework: Flutter (cross-platform iOS/Android), Material 3
- Runtime: Flutter SDK ^3.10.9
- Backend: Supabase (PostgreSQL + RLS, Auth, Realtime, Storage)
- Payments: Stripe (planned — edge function scaffold exists)
- Push Notifications: OneSignal (Phase 2, not yet wired)
- Phase 2 additions: Twilio SMS, Mapbox, Stripe Connect

## User Roles
| Role | DB value | Screen |
|---|---|---|
| Resident | `resident` | ResidentDashboardScreen |
| Driver/Porter | `driver` | WorkerDashboardScreen |
| Property Manager | `property_manager` | PropertyManagerDashboardNewScreen |
| Super Admin | `super_admin` | OwnerDashboardScreen |

## Primary Goals
- Residents sign up via invite code + unit number, then track their service
- Drivers see and execute nightly pickup routes; report violations with photos
- Property managers view completion rates and violation history per property
- Super admin manages the entire platform

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
- Stripe Connect contractor payouts not implemented yet (webhook edge function scaffold only)
- OneSignal push tokens not collected or stored yet
- Admin dashboard (`admin_dashboard/`) is scaffolded but not validated against current DB schema
- `main_simple.dart` exists as a simpler alternate entry point — purpose unclear
