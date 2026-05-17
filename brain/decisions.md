# Decisions Log

## Format
- Date | Decision | Reason | Alternatives Considered | Impact

---

### 2026-05-15
- **Decision**: Dropped and recreated `invite_codes` table during migration 005.
- **Reason**: Legacy table had an incompatible schema (`invite_code TEXT` column name and `unit_number TEXT` instead of `unit_id UUID FK`). The existing 3 seed rows were expendable.
- **Alternatives Considered**: ALTER TABLE to rename/retype columns (would have been messier with FK constraints).
- **Impact**: Old invite codes were cleared. Seed data must be re-applied via `010_seed_invite_codes.sql`.

### 2026-05-15
- **Decision**: Dropped and recreated `verify_invite_code` and `claim_invite_code` functions during migration 005.
- **Reason**: Old function signatures had a different return type that conflicted with the new schema. PostgreSQL won't let you `CREATE OR REPLACE` a function with a different return type.
- **Alternatives Considered**: Use a different function name — rejected because the Flutter app already calls these by name.
- **Impact**: Both RPCs now match the new `invite_codes` schema and are callable by `anon` + `authenticated`.

### 2026-05-15
- **Decision**: `violations.pickup_id` made nullable.
- **Reason**: Workers need to file violations without an associated pickup (e.g., during property walkthroughs). The original NOT NULL constraint was too restrictive.
- **Alternatives Considered**: Keep NOT NULL and require a dummy pickup record — rejected as data pollution.
- **Impact**: Violation reports from `ViolationReportScreen` can now be created without a pickup context.

### 2026-05-15
- **Decision**: `notifications.user_id` made nullable; added `property_id`, `sender_id`, `is_active`, `metadata` columns.
- **Reason**: Notifications needed to support two modes: (1) direct to a user, (2) broadcast to all residents of a property. Original schema only supported direct targeting.
- **Alternatives Considered**: Separate table for broadcast notifications — rejected to keep queries simple.
- **Impact**: RLS policy now covers both modes. `SimpleNotificationSenderScreen` can target a property.

### 2026-05-15
- **Decision**: Installed Repo OS (brain/ + .cursor/rules/ + cursor-os/) structure.
- **Reason**: Project needs persistent memory for resumable AI-assisted development sessions.
- **Alternatives Considered**: Ad-hoc notes, no shared memory system.
- **Impact**: Future sessions should open brain files first and have consistent context.

### (Original — pre-migration)
- **Decision**: Use SECURITY DEFINER RPCs for invite code verification and claiming.
- **Reason**: `invite_codes` table is locked down with RLS (`FOR SELECT USING (false)`). The only access is through controlled functions that validate the caller's identity.
- **Alternatives Considered**: Give authenticated users SELECT on invite_codes — rejected due to code enumeration risk.
- **Impact**: `verify_invite_code(code, property_id, unit_number)` and `claim_invite_code(invite_id, user_id)` are the only paths to use an invite.

### (Original — pre-migration)
- **Decision**: Role routing at the app level — `RoleHome` queries `users.role` and pushes the correct screen.
- **Reason**: Single Flutter codebase serves four distinct user types. Simpler than separate builds.
- **Alternatives Considered**: Separate apps per role — rejected as overkill for Phase 1.
- **Impact**: All roles share one app binary. Any role confusion would be caught at the `users.role` query.
