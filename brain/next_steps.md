# Next Steps

## ✅ Supabase project switch — COMPLETE (2026-08-19)

Live on the dedicated project **`immiejqvnucndjspacwv`**. Schema applied, security audited,
backend built out, and verified against the live API.

**Verified working:** 33 tables with RLS on all of them, 122 policies, **0 Security Advisor
errors**, all 7 demo accounts log in, every role correctly scoped, both Edge Functions deployed,
private `violations` storage bucket, auth URLs + password policy configured.

**Ten migrations added** (`016`–`025`) fixing four latent defects and six security/access
findings — including a confirmed data leak in `audit_logs` and a Stripe webhook bug that would
have charged customers without delivering credits. Full detail: `supabase/MIGRATIONS.md`.

### Stress-test findings (2026-08-20) — all fixed and verified

Probed every role against the live API and ran the app. Migrations `026`–`029`.

| Severity | Finding |
|---|---|
| **HIGH** | Residents could `PATCH purchased_comeback_balance = 9999` — unlimited paid comebacks, Stripe bypassed |
| **HIGH** | Residents could `PATCH property_id` and relocate to another property, gaining read access to it |
| **HIGH** | **Every photo upload was silently rejected** (403). Pickup proof, stop completion and missed-pickup photos all looked saved and never were |
| **HIGH** | **Workers could never file a violation** — the resident lookup had no policy for the driver role, so the screen always bailed |
| **HIGH** | **The PM dashboard was blind** on 10 tables — the app assigns PMs via `user_properties`, the policies checked `company_id` |
| **MED** | `ViolationReportScreen` and `ResidentReportMissedPickupScreen` were fully built but unreachable |
| **MED** | Owner Financials cards overflowed at every viewport, clipping the labor subtitles |
| **LOW** | `simple_auth_screen_test` had been red against main |

### Resolved 2026-08-20 — reliability pass

- **All 42 silent `catch (_) {}` blocks eliminated.** Six were losing data while
  telling the user it worked (clock-in → unpaid hours, comeback flagging, comeback
  completion, message send, rating, invite verification). The other 37 are optional
  reads that now log via `ErrorReporter.logSilent` instead of vanishing.
- **Apple sign-in nonce handshake fixed** — it passed `authorizationCode` as the nonce
  and never sent one to Apple, so it could not have worked even once configured.
- **`ResidentServiceCalendarScreen` wired in** (service windows + holiday schedule).

### Native platform — VERIFIED ON BOTH iOS AND ANDROID (2026-08-20)

Not compile-checked: both features run on real devices.

| Test | iOS (iPhone 17 Pro sim) | Android (Pixel 7 emu) |
|---|---|---|
| `path_provider` linked, writable dir | PASS | PASS |
| `geolocator` responds to platform calls | PASS | PASS |
| `getPlatformLocation` returns fix or null | skipped¹ | **PASS (real fix)** |
| `getPlatformLocation` bounded, never throws | PASS | PASS |
| `downloadCsv` writes the file | PASS | PASS |

¹ iOS skips when permission is not pre-granted; Android ran the full path with
`adb shell pm grant`, so the whole geolocator chain is exercised there.

**🔴 A hard Android release blocker was found and fixed.** The app could not be built
for Android *at all*:

```
sign_in_with_apple-5.0.0/.../SignInWithApplePlugin.kt:17:48
    Unresolved reference 'Registrar'      <- Flutter's removed v1 plugin API
```

Every Android build died there — debug, release, Play Store bundle. It could not be
bumped directly because `supabase_flutter 1.10.25` pins `sign_in_with_apple <6.0.0`,
so it arrives transitively. Fixed with a documented `dependency_overrides` pin to
`^6.1.4` (v2 embedding); the app's calls are identical across both versions.

- [x] ~~Plan a `supabase_flutter` 1.10.25 → 2.x upgrade~~ — **done 2026-08-20**, now on
      **2.16.0** and the `dependency_overrides` stopgap is removed. It turned out far
      smaller than expected: the codebase had **zero `.execute()` calls**, so the real
      breaking surface was 9 errors in 3 files (`Provider`→`OAuthProvider`, the
      realtime `.on()`→`.onPostgresChanges()` API, and `authCallbackUrlHostname`
      which v2 auto-detects). Verified on web (live owner login), iOS and Android.

- [ ] **Test password-reset deep linking** once SMTP exists. v2 handles
      `com.relaxedliving.valet://login-callback` automatically through `app_links`
      rather than the old `authCallbackUrlHostname`, and that path has **not** been
      exercised — it needs a real reset email. Whitelist the redirect under
      Auth → URL Configuration.

- [ ] ⚠️ **`flutter clean` after any dependency change.** A stale
      `web_plugin_registrant.dart` made the web build fail with what looked like a
      broken `app_links` package. It is not; it is a caching artifact.

Toolchains are installed and reproducible (all under `$HOME`, removable with
`rm -rf ~/.jdks ~/Library/Android`):

```bash
# iOS - CocoaPods on macOS's Ruby 2.6 needs pinned gems
export GEM_HOME="$HOME/.gem/ruby/2.6.0"; export PATH="$GEM_HOME/bin:$PATH"
flutter build ios --simulator --debug --dart-define-from-file=dart_define.json

# Android
export JAVA_HOME="$HOME/.jdks/jdk-17.0.13+11/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
emulator -avd rlv_test -no-snapshot -no-boot-anim -gpu swiftshader_indirect &
adb shell pm grant com.relaxedliving.valet android.permission.ACCESS_FINE_LOCATION
adb emu geo fix -96.7970 32.7767
flutter test integration_test/native_platform_test.dart -d emulator-5554 \
  --dart-define-from-file=dart_define.json
```

⚠️ Still unexercised: a **physical handset**, and the share sheet's own presentation
(cannot be asserted headlessly) — one manual tap on the first TestFlight build.

### GitHub integration — NOT a defect (corrected 2026-08-20)

Earlier notes said it "still points at the old project". Checked the dashboard:
**the new project has no GitHub integration connected at all.** Migrations were
applied manually via `supabase/provision/`, so nothing is deploying to the wrong
database. Connecting it is an optional convenience and needs a GitHub OAuth grant,
which is the owner's to give.

### Static mockups — audited 2026-08-20

Every screen was checked for a data layer. **`resident_service_calendar_screen` was
the only static mockup left**, and it was showing wrong information:

- Hardcoded `6:00 PM - 10:00 PM` for everyone. Oakwood Heights runs **17:30-21:30**,
  so those residents were told the wrong time for their own pickup. Now reads
  `properties.service_window_start/end` for the resident's own property and labels it
  with the property name.
- Floating federal holidays pinned to fixed dates — MLK Jan 15, Memorial May 27,
  Labor Sep 2, Thanksgiving Nov 28. All four were wrong. The running app marked
  **Sep 2 2026, a Wednesday, as Labor Day** (real date: Sep 7). Now computed.
- `weekday <= 4` excluded Sunday while the legend said "Sunday - Thursday".

Covered by 14 tests (OPM-verified holiday dates for 2026-2028, all seven weekdays,
time formatting incl. Oakwood's 17:30).

Everything else queries Supabase. `simple_auth_screen` and `change_password_screen`
have no table queries because they use the auth API — that is correct, not a mockup.

### Dead code — removed 2026-08-20

All five unimported screens deleted (2,051 lines). Every screen in `lib/` is now
reachable from the running app. Each was checked for unique value first:

- `property_manager_dashboard_screen` — 882 lines, **zero** `.from()` calls; a static
  mockup with no data layer, superseded by `property_manager_dashboard_new`.
- `manager_alerts_screen` — written against `002_notifications.sql`, the alternate
  schema we never run. Verified live: its insert returns *"Could not find the
  'audience' column"*. It would have failed on **every** send. Its apparent edge over
  the wired sender (target by email) was never implemented either.
- `resident_extra_services_screen` — strict subset of `resident_services_screen`.
- `resident_services_screen` / `manager_property_services_screen` — every action was a
  "coming soon" toast.

The product intent from the three stubs is preserved in
`brain/future_services_catalog.md`, including how to build one on top of
`service_requests` and the existing Stripe path.

### OAuth — accounts required before Apple/Google sign-in works

The buttons are on the login screen and fail with a clear message until configured.

- **Google:** free. A Google Cloud project + OAuth client IDs (separate ones for web,
  iOS and Android), then paste the client ID/secret into Supabase → Auth → Providers.
- **Apple: requires the Apple Developer Program, $99/year.** You need a Services ID,
  a Sign in with Apple key (.p8) and your Team ID. You already need this account for
  TestFlight and the App Store, so it is not an extra cost — just a prerequisite.
- **Apple's rule matters here:** App Store Guideline 4.8 requires offering Sign in
  with Apple if you offer any other third-party sign-in. So on iOS you cannot ship
  Google-only — it is both or neither.
- Until then: either configure both, or hide the two buttons. Email/password works
  today and is what all six roles use.

### Backend performance — audited and tuned 2026-08-21

Timed every role/table pair against the live API rather than assuming the RLS work
was done. Two real findings, both fixed and verified:

| Finding | Before | After |
|---|---|---|
| `pm_has_unit()` had no role guard, so a **resident** reading `violations` ran a 4-table join per row (migration `030`) | 1.87s | **0.33s** |
| 61 policies called `auth.uid()` bare, re-evaluating it per row instead of once per query (migration `031`) | 294 Advisor warnings | **233** |

Access matrix (19 tables × 5 roles) captured before and after and diffed — **identical**.
All attack probes still blocked. Advisor: **0 errors** on both Security and Performance.

- [ ] **233 "Multiple Permissive Policies" warnings remain — deliberately.** Each table
      carries separate policies for owner, ops, PM, worker and resident, so Postgres
      evaluates all of them and ORs the results. Collapsing them into one merged policy
      per table/command would be a redesign of the whole authorisation model, with real
      regression risk, and the split is exactly what the verified access matrix is built
      on. Worth doing only with the row-count matrix as a regression harness, deliberately,
      not as a late-session tidy-up.

### Remaining — owner action only### Remaining — owner action only (I can't do these)

- [ ] **Set the Stripe secrets** on the new project: `STRIPE_SECRET_KEY`,
      `STRIPE_WEBHOOK_SECRET`, `APP_ORIGIN` (Edge Functions → Secrets). Both functions are
      deployed and currently return a graceful `503 "Stripe is not configured"`. Needs the
      real Stripe account — see `brain/stripe_setup.md`.
- [ ] **Point the Stripe webhook endpoint** at
      `https://immiejqvnucndjspacwv.supabase.co/functions/v1/stripe-webhook`.
- [ ] **Re-link the GitHub integration** to the new project, or migrations keep deploying to
      the old one.
- [ ] **Configure custom SMTP** before public launch. The built-in mailer is capped at ~2–3
      emails/hour, so password reset is effectively unusable at scale. Once SMTP is in place you
      may want email confirmation back on — but that needs an app change first (see below).
- [ ] **Upgrade to Pro** if you want leaked-password protection (HaveIBeenPwned) — Free can't.

### Follow-ups that need app changes first

- [ ] **"Require current password when updating" / "Secure password change"** are OFF on
      purpose. `change_password_screen.dart` calls `updateUser(password:)` without the old
      password and the same screen handles recovery, so enabling either would break password
      reset. Add re-authentication to the screen, then enable.
- [ ] **Re-enabling email confirmation** needs `resident_signup_screen.dart` to handle
      `signUp()` returning no session (it currently calls `claim_invite_code` straight after).
- [ ] Two real resident accounts (`devinbooker817@`, `powellreggie23@`) have unknown passwords —
      they can only be re-invited, not recreated.
- [ ] **Apply `016`–`025` to the OLD project** if it stays in use — it carries every one of
      these defects, including the audit-log leak.
- [ ] Tell the client the run command changed: `--dart-define-from-file=dart_define.json`.
- [ ] `flutter clean` before the next deploy build (stale `build/web/assets/.env` from May).

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
- [x] Brain refresh with ordered Step 1 legal playbook — `5e86663`
- [x] Stripe Checkout wiring — `7c5d417`
- [x] Brain: site, iPad LAN demo, TestFlight path, RLS advisor (Aug 18)

---

## Next Features (after pilot)

- [ ] Bulk unit import + bulk invite code generate
- [x] Stripe paid comebacks + pickup packs checkout (code + migration 015; secrets/deploy still owner action)
- [ ] Push notifications (FCM/APNs)
- [ ] Steps / activity tracking (deferred)

---

## Technical Debt

- [ ] `supabase_flutter` v1 → v2 upgrade
- [ ] `main_simple.dart` — remove or document
- [ ] Integration tests for invite + RLS regression
- [ ] Tighten `notifications` INSERT policy (permissive in 004)
