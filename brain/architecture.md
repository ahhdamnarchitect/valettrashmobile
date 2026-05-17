# Architecture

## High-Level Design
Flutter mobile app (single codebase) talks to Supabase over REST/realtime. Auth state drives role-based routing to separate dashboard screens. Supabase handles auth, database (PostgreSQL with RLS), file storage (violation photos), and will eventually host Stripe webhook edge functions.

## Directory Structure
```
valettrashmobile/
├── mobile/                        # Flutter app
│   └── lib/
│       ├── main.dart              # Entry — loads .env, inits Supabase, runs ValetApp
│       ├── main_simple.dart       # Alternate simpler entry (purpose TBD)
│       ├── valet_app.dart         # MaterialApp + AuthGate + RoleHome
│       └── features/
│           ├── auth/screens/      # SimpleAuthScreen, ResidentSignupScreen
│           ├── resident/screens/  # ResidentDashboardScreen
│           ├── worker/screens/    # WorkerDashboardScreen, ViolationReportScreen
│           ├── manager/screens/   # PropertyManagerDashboardNewScreen, SimpleNotificationSenderScreen
│           ├── owner/screens/     # OwnerDashboardScreen
│           └── test/screens/      # TestConnectionScreen
├── supabase/
│   ├── migrations/                # SQL migrations (apply in order — see MIGRATIONS.md)
│   ├── functions/                 # Edge functions (stripe-webhook)
│   └── seed_data/                 # Test data (invite codes etc.)
└── admin_dashboard/               # Web admin UI (scaffolded, not validated)
```

## Key Modules

- `valet_app.dart` — root widget; `AuthGate` listens to Supabase auth stream; `RoleHome` fetches `users.role` and routes to the correct dashboard
- `features/auth/` — sign-in + resident sign-up flow (invite code verification → account creation → claim invite)
- `features/resident/` — resident's pickup status, service window countdown, notifications
- `features/worker/` — driver route list, pickup marking, violation report with `image_picker` + Supabase Storage upload
- `features/manager/` — property manager dashboard + notification sender
- `features/owner/` — super admin dashboard

## Entry Points
- `mobile/lib/main.dart` — production entry
- `mobile/lib/main_simple.dart` — alternate (possibly used for isolated testing)

## Data Flow
1. User opens app → `AuthGate` checks `Supabase.auth.currentSession`
2. If no session → `SimpleAuthScreen` (login or sign up)
3. Resident signup: verify invite code via `verify_invite_code()` RPC → create auth user → insert `public.users` row → call `claim_invite_code()` RPC → insert `resident_units` row
4. If session exists → `RoleHome` queries `public.users.role` → routes to dashboard
5. Worker violation report: `image_picker` → upload to `storage.objects` (`violations/workers/<uid>/...`) → insert `public.violations` row referencing the file URL

## Database Schema (key tables)
| Table | Purpose |
|---|---|
| `users` | All users; `role` column drives app routing |
| `properties` → `buildings` → `floors` → `units` | Property hierarchy |
| `resident_units` | Links residents to their unit + property |
| `invite_codes` | One-time codes; verified + claimed via SECURITY DEFINER RPCs |
| `user_properties` | Links managers/admins to properties they manage |
| `pickups` | Nightly pickup events per route |
| `violations` | Violations filed by drivers; optional `pickup_id` (nullable) |
| `notifications` | Targeted (by `user_id`) or broadcast (by `property_id`) |
| `routes` / `worker_assignments` | Route scheduling and driver assignment |
| `subscriptions` / `invoices` | Billing (Stripe integration target) |

## External Integrations
- **Supabase** — auth, database, storage, edge functions
- **Stripe** — billing (edge function scaffold: `supabase/functions/stripe-webhook/`)
- **OneSignal** — push notifications (Phase 2, not yet implemented)
- **Twilio** — SMS reminders (Phase 2)
- **Mapbox** — route mapping for drivers (Phase 2)

## Risks / Fragile Areas
- `verify_invite_code` RPC walks the `units → floors → buildings → properties` hierarchy — needs accurate seed data or unit lookup returns null
- `supabase_flutter` v1.x is pinned; v2 migration will be a breaking change (API surface changed significantly)
- `mobile/.env` must exist with correct keys before running the app — no fallback UI for missing config
- `main_simple.dart` has an unclear relationship to `main.dart` — could cause confusion
