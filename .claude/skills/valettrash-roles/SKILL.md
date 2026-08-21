---
name: valettrash-roles
description: Use when working on Relaxed Living Valet role dashboards, auth, or the Supabase backend — the six user roles, their dashboards/permissions, and RLS role gating across the Flutter app and admin. Reconciled against brain/current_state.md and the live schema.
---

# Relaxed Living Valet — roles & RLS conventions

**Ground truth is `brain/current_state.md`, NOT the committed migrations** (they under-represent the live schema — see the enum caveat). And verify against the owner's upstream first: this repo is forked from the business owner's GitHub and may have drifted — see `brain/current_state.md` fork-sync note.

## The six app roles
The Flutter `RoleHome` switch in `valet_app.dart` routes **six** roles:

| Role (`user_role` value) | Dashboard screen | Theme / accent |
|---|---|---|
| `resident` | `ResidentDashboardScreen` | dark / emerald |
| `driver` | `WorkerDashboardScreen` | dark / amber |
| `operations_manager` | `ManagerDashboardScreen` | dark / indigo |
| `property_manager` | `PropertyManagerDashboardNewScreen` | light |
| `owner` | `OwnerDashboardScreen` | light / purple |
| `super_admin` | `AdminDashboardScreen` | light / info |

**Naming gotchas:**
- `driver` is the field worker — screen is `WorkerDashboardScreen` and DB columns say `worker_*` (`worker_id`, `worker_assignments`), but the enum value is `driver`.
- `super_admin` → `AdminDashboardScreen`; `owner` → `OwnerDashboardScreen`. Don't swap them (older brain files mislabeled super_admin as the Owner screen).

## ⚠️ Migrations under-represent the schema — do not trust `000_enums.sql` as complete
- `supabase/migrations/000_enums.sql` declares only **4** values: `resident, driver, property_manager, super_admin`.
- `operations_manager` and `owner` were added to the **live** Supabase enum via ad-hoc `ALTER TYPE user_role ADD VALUE …` run directly against the remote DB — **never captured as a migration file.** The live DB has all 6.
- `004_rls_policies.sql` was written against the original 4 roles; `operations_manager`/`owner` may lack explicit committed RLS policies — verify against the live DB before relying on RLS for those two.

## RLS patterns (from the committed policies)
- Role check: `EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = '<role>')`.
- Ownership: `resident_user_id = auth.uid()`, `worker_id = auth.uid()`, PM via `properties.company_id = auth.uid()`; `super_admin` has `FOR ALL` on every table.
- Hierarchy cascades **properties → buildings → floors → units**; child tables re-derive access by joining up to properties.
- **RLS is enabled on every table.** New tables ship enable-RLS + per-role policies in the same numbered `NNN_*.sql` migration. Users may update their own profile but not their own `role`.

## Consistency
- Flutter route/nav guards must mirror all **six** roles.
- Never cross-quote this client's schema into other projects (client_confidential).
