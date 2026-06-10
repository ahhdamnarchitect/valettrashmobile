# Next Steps

## 🚀 Go-Live — Active (see `brain/go_live_checklist.md`)

### Phase 0 — This week
- [ ] **Apply migration `012_workforce_labor.sql`** on hosted Supabase
- [ ] **Apply migration `013_unify_owner_role.sql`** on hosted Supabase
- [ ] **Apply migration `014_launch_rls_hardening.sql`** on hosted Supabase
- [ ] Run **`supabase/tests/rls_role_smoke.sql`** — zero tables without RLS
- [ ] **Owner/Admin switch QA** — top bars both directions
- [ ] **Workforce QA** — clock in → OM ON DUTY → owner labor $
- [ ] **Resident signup QA** — invite code end-to-end
- [ ] **PM property scope QA** — invite codes only for assigned properties after RLS

### Phase 1 — Security (pilot blocker)
- [ ] Production Supabase Site URL + Redirect URLs (not localhost)
- [ ] Email provider for password reset (Resend/SendGrid)
- [ ] Remove test accounts from production project
- [ ] Stripe Connect webhooks live

### Phase 2 — Pilot (2–4 properties)
- [ ] Onboard property per `brain/resident_invite_workflow.md`
- [ ] Error monitoring (Sentry/Crashlytics) in release builds
- [ ] Support runbook for owner/PM

### Phase 3 — App stores
- [ ] `flutter build appbundle --release` (Android)
- [ ] `flutter build ipa --release` (iOS — requires Mac)
- [ ] Privacy policy URL + store listings
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

## QA (in progress)

- [ ] **Resident dashboard retest** — `brain/current_state.md` checklist
- [x] **Commit & push** owner/admin two-way switch — `8b5b8aa` / `c5af2db` (May 19, 2026)
- [x] **Commit & push** go-live checklist + RLS migration 014 — `2f0c9b8` on `main` (May 19, 2026)

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
- [ ] Tighten `notifications` INSERT policy (currently permissive in 004)

---

## Completed Sessions (summary)

See `brain/change_log.md`. Latest: owner/admin switch (`8b5b8aa`), workforce labor (`401b13e`), unified owner login (`eb29777`).
