# Next Steps

## Ordered go-live sequence (do in order)

See **`brain/go_live_checklist.md`** for full detail.

### Step 1 — Legal & business (protect the owner)
- [ ] LLC / corporation confirmed
- [ ] Liability + E&O insurance
- [ ] Property management agreements (lawyer review)
- [ ] Worker / contractor agreements
- [ ] Privacy Policy at public URL
- [ ] Terms of Service at public URL
- [ ] Support / contact page

### Step 2 — Database security (this week)
- [ ] **Apply `012_workforce_labor.sql`** on hosted Supabase
- [ ] **Apply `013_unify_owner_role.sql`** on hosted Supabase
- [ ] **Apply `014_launch_rls_hardening.sql`** on hosted Supabase
- [ ] Run **`supabase/tests/rls_role_smoke.sql`** — zero tables without RLS
- [ ] Supabase Database Linter — clear security warnings

### Step 3 — Role QA (after RLS)
- [ ] Owner/Admin switch both directions
- [ ] Resident invite signup end-to-end
- [ ] Worker clock in → OM ON DUTY → owner labor $
- [ ] PM invite codes only for assigned properties
- [ ] Staff invite → correct role dashboard

### Step 4 — Environments & auth
- [ ] Staging Supabase project (fake data only)
- [ ] Production Supabase project (no test accounts)
- [ ] Production Site URL + Redirect URLs (not localhost)
- [ ] Email provider (Resend/SendGrid) for password reset
- [ ] `service_role` never in Flutter; anon key only

### Step 5 — Pilot (1–2 properties)
- [ ] Onboard per `brain/resident_invite_workflow.md`
- [ ] Support runbook (reset password, re-issue invite, wrong role)
- [ ] Error monitoring (Sentry/Crashlytics) in release builds
- [ ] Stripe Connect webhooks if charging during pilot

### Step 6 — App stores
- [ ] Link Privacy + Terms in app + store listings
- [ ] Play Data safety / Apple App Privacy labels
- [ ] `flutter build appbundle --release` (Android)
- [ ] `flutter build ipa --release` (iOS — Mac + Apple Developer)
- [ ] Native GPS (`geolocator`) + CSV `share_plus`

---

## Before Submitting to Stores (reference)

- [x] **Final app icon** — RLV logo installed (May 2026)
- [ ] **iOS signing** — macOS + Xcode + Apple Developer ($99/yr)
- [ ] **Android release build** — `flutter build appbundle`
- [x] Migrations **007–011** applied live
- [ ] Migrations **012–014** apply on hosted
- [ ] **Re-enable RLS** — migration 014 + smoke test
- [ ] **App Store / Play Store listing** — screenshots, privacy policy

---

## QA / pushes completed

- [x] Owner/admin two-way switch — `8b5b8aa` / `c5af2db`
- [x] Go-live checklist + RLS migration 014 — `2f0c9b8`
- [ ] Brain refresh with ordered Step 1 legal playbook — this session

---

## Next Features (after pilot)

- [ ] Bulk unit import + bulk invite code generate
- [ ] Stripe paid comebacks + pickup packs checkout
- [ ] Push notifications (FCM/APNs)
- [ ] Steps / activity tracking (deferred)

---

## Technical Debt

- [ ] `supabase_flutter` v1 → v2 upgrade
- [ ] `main_simple.dart` — remove or document
- [ ] Integration tests for invite + RLS regression
- [ ] Tighten `notifications` INSERT policy (permissive in 004)
