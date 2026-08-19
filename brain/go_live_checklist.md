# Go-Live Checklist — Relaxed Living Valet

**Goal:** Demo to apartment complexes → pilot 2–4 properties → App Store / Play Store release with production-grade security.

**Current readiness (Aug 2026):**
| Milestone | Estimate |
|---|---|
| Sales demo (web on PC, test data) | **Ready now** (`localhost:8091`) |
| iPad in-person (Safari + same Wi-Fi LAN IP) | **Ready now** if PC is running Flutter |
| iPad installable (TestFlight) | Needs Apple Developer + Mac |
| Limited pilot (1–2 properties, monitored) | After RLS 012–014 + Stripe secrets |
| Public store launch (hardened) | After TestFlight + Privacy/Terms + native GPS/CSV |

No app is “unhackable.” Target: **RLS everywhere**, least privilege, monitoring, and incident runbooks.

---

## Step 1 — Legal & business foundation (do before real residents)

Protects *you* as the company. Prefer lawyer-reviewed templates.

| # | Action | Status |
|---|---|---|
| 1 | LLC / corporation confirmed | [x] |
| 2 | Business bank account (for Stripe) | [ ] |
| 3 | General liability + E&O insurance | [ ] |
| 4 | Property management agreements (per complex) | [ ] |
| 5 | Worker / contractor agreements | [ ] |
| 6 | **Privacy Policy** published at public URL | [ ] (site live: relaxlivingvalet.com) |
| 7 | **Terms of Service** published at public URL | [ ] |
| 8 | Support / contact page; cookie notice if marketing site | [ ] site: **https://relaxlivingvalet.com** |

**First technical step after (or parallel):** apply migrations `012` → `013` → `014` on hosted Supabase.

---

## Phase 0 — Security + QA (this week)

### Database
- [ ] Apply pending migrations on hosted Supabase **in order**:
  - `012_workforce_labor.sql`
  - `013_unify_owner_role.sql`
  - `014_launch_rls_hardening.sql`
- [ ] Run `supabase/tests/rls_role_smoke.sql` in SQL editor after 014
- [ ] Re-run Supabase **Database Linter** → security advisors should show no RLS-off tables

### App QA (all roles)
- [ ] Owner: Staff login → Financials → Admin Portal switch (both directions)
- [ ] Resident: invite signup → home → comeback → extra service
- [ ] Worker: clock in → share location → OM sees ON DUTY
- [ ] PM: Properties → occupied/vacant → export unit codes CSV
- [ ] OM: Workforce & Timecards → Live Worker Map

### Environment
- [ ] Keep **dev** on `localhost:8091` with current project ref
- [ ] Plan **staging** Supabase project (copy schema, no real resident PII)
- [ ] Plan **prod** Supabase project (separate keys, no test accounts)

---

## Phase 1 — Security sprint (blocker for pilot)

### Row Level Security
- [x] Migration `014_launch_rls_hardening.sql` in repo (helpers + enable RLS + satellite policies)
- [ ] Apply 014 on hosted DB
- [ ] Verify each role can only access expected rows (see smoke test)
- [ ] Fix any broken screens after RLS (common: admin list queries, PM property scope)

### Auth & abuse
- [ ] Production Site URL + Redirect URLs (not localhost)
- [ ] Email provider (Resend/SendGrid) for password reset
- [ ] Rate-limit strategy for invite verification (Supabase Auth + RPC validation)
- [ ] Remove or gate test accounts in production

### Secrets
- [ ] `service_role` key **never** in Flutter app
- [ ] Only `SUPABASE_ANON_KEY` in client `.env`
- [ ] Rotate keys if ever exposed in chat/logs

### Policies to audit manually
| Table | Who reads | Who writes |
|---|---|---|
| `users` | self; owner/admin all | self (not role); owner/admin |
| `invite_codes` | owner/admin; PM own properties | owner/admin |
| `resident_units` | resident self; PM/owner scoped | signup RPC + admin |
| `clock_events` | worker self; OM/owner | worker self |
| `service_requests` | resident self; owner/admin | resident insert; owner update |

---

## Phase 2 — Pilot operations (2–4 properties)

### Onboarding
- [ ] Follow `brain/resident_invite_workflow.md` end-to-end per property
- [ ] Bulk unit import (backlog — manual entry OK for pilot)
- [ ] Assign PM + OM + driver per property

### Payments (if charging during pilot)
- [ ] Stripe Connect account + webhook endpoint live
- [ ] `contractor_payouts` / subscriptions sync from webhooks
- [x] Paid comebacks + pickup packs checkout (code live; set Stripe secrets + webhook)
- [ ] Deploy Edge Functions + `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` (`brain/stripe_setup.md`)

### Monitoring
- [ ] Error tracking (Sentry or Crashlytics) in release builds
- [ ] Supabase log alerts for auth failures / 5xx
- [ ] Weekly review: failed signups, webhook failures, RLS errors

### Support runbook
- [ ] Document: reset password, re-issue invite, fix wrong role, missed pickup escalation
- [ ] Owner contact + on-call for pilot properties

---

## Phase 3 — Store release

### Android
- [ ] `flutter build appbundle` (release)
- [ ] Upload to Play Console → Internal testing → Production
- [ ] Privacy policy URL + Data safety form

### iOS
- [ ] macOS + Xcode + Apple Developer ($99/yr) — **cannot build from Windows**
- [ ] `flutter build ipa`
- [ ] **TestFlight first** for apartment walkthroughs (internal testers)
- [ ] Public App Store review after Privacy/Terms URLs
- [ ] Privacy nutrition labels

### App metadata
- [ ] Screenshots (phone + tablet)
- [ ] Description, keywords, support URL
- [ ] Deep link `com.relaxedliving.valet://login-callback` verified on device

### Native gaps (before store, not blocking web pilot)
- [ ] Worker GPS: replace `dart:html` with `geolocator`
- [ ] CSV export: `share_plus` on native
- [ ] Push notifications (FCM/APNs) — post-pilot

---

## Phase 4 — Production hardening (post-launch)

- [ ] Separate staging/prod CI deploy pipelines
- [ ] Automated RLS regression tests
- [ ] Backup restore drill (Supabase PITR)
- [ ] Penetration test or third-party security review
- [ ] `supabase_flutter` v2 upgrade (when deps allow)

---

## Release builds (leave debug mode)

**Web (demo / internal):**
```powershell
cd mobile
flutter build web --release
# Serve build/web/ behind HTTPS reverse proxy — not flutter run
```

**Android:**
```powershell
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

**iOS (macOS only):**
```powershell
flutter build ipa --release
```

Use `.env` with **production** `SUPABASE_URL` and anon key for release builds. Never ship `service_role`.

---

## Files for this effort

| File | Purpose |
|---|---|
| `supabase/migrations/014_launch_rls_hardening.sql` | RLS enable + owner policies + satellite tables |
| `supabase/tests/rls_role_smoke.sql` | Post-migration verification queries |
| `brain/test_credentials.md` | Test logins (dev only) |
| `brain/resident_invite_workflow.md` | Property onboarding playbook |

---

## Resume after each session

1. Check `brain/next_steps.md` for unchecked Phase 0/1 items
2. Apply any new migrations on hosted Supabase
3. Run role smoke tests if RLS changed
4. Log results in `brain/change_log.md`
