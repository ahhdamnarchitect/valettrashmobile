# Next Steps

## Before Submitting to Stores (action required from you)

- [ ] **Final app icon** — replace `assets/icon/app_icon.png` and `app_icon_foreground.png` with final artwork (1024×1024 PNG), then run:
  ```powershell
  flutter pub run flutter_launcher_icons
  flutter pub run flutter_native_splash:create
  ```
- [ ] **iOS signing** — requires macOS + Xcode + Apple Developer account ($99/yr):
  1. Open `ios/Runner.xcworkspace` in Xcode
  2. Set your Apple team under Signing & Capabilities
  3. `flutter build ipa` to produce the `.ipa` for App Store Connect
- [ ] **Android release build** — keystore already configured, run from a machine with Android SDK:
  ```
  flutter build appbundle
  ```
  Upload the `.aab` to Google Play Console
- [ ] **Production Supabase config** — when deploying to a real domain:
  - Update Site URL from `http://localhost:8091` to `https://yourdomain.com`
  - Add `https://yourdomain.com` to Redirect URLs
  - Enable a real email provider (Resend / SendGrid) for confirmation and reset emails
- [ ] **App Store / Play Store listing** — screenshots (6.7" iPhone, 12.9" iPad for iOS; multiple densities for Android), app description, keywords, age rating, privacy policy URL

---

## Next Features (prioritized)

- [ ] **Stripe paid comeback requests** — in-app UI placeholder already exists; blocked on Stripe account + webhook secret. Once you have those, wire `stripe_checkout` into `ResidentComebackRequestScreen`
- [ ] **Push notifications** — defer until native build is in TestFlight / Play Store internal testing:
  - Android: FCM (Firebase Cloud Messaging) — free
  - iOS: APNs via FCM or OneSignal — requires Apple Developer account
- [ ] **Worker location on native** — currently uses `dart:html` (web only). Swap to `geolocator` package for iOS/Android builds
- [ ] **CSV export on native** — `PmComplianceReportScreen` uses `dart:html` for download. Swap to `path_provider` + `share_plus` for native builds

---

## Technical Debt

- [ ] `supabase_flutter` v1 → v2 upgrade — **BLOCKED** in this environment (missing transitive deps). Try on a machine with full internet/VPN access
- [ ] `main_simple.dart` — unclear purpose, remove or document
- [ ] Integration tests for invite code flow
- [ ] Confirm `AdminDashboardScreen` RLS policies cover all edge cases with real data at scale

---

## Completed Sessions (summary)

All prior work is complete and documented in `brain/change_log.md`. Summary:

| Session | Key deliverable |
|---|---|
| 1–3 | Initial setup, Supabase schema, seed data, all 6 dashboards connected to real data |
| 4 | Auth bug fixes, OM/PM/Worker test accounts, role routing |
| 5–7 | Dark redesign (all dashboards), violation report, map, worker earnings, vacation hold, CSV export, realtime worker map |
| 8 | Comeback request flow, resident concerns, admin portal (5 tabs), admin RLS |
| 9 | super_admin account, password reset + visibility toggle (all dashboards), Supabase URL config |
| 10 | Owner routing fix, Android + iOS platform setup, permissions, signing, icons, splash, deep links |
