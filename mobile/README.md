# Relaxed Living Valet — Mobile App

Flutter app for the full valet trash operation. Six role-based dashboards — resident, worker, operations manager, property manager, owner, and super admin — all wired to live Supabase data. Feature-complete and brand-aligned to the RLV design sheet. Ready for Stripe integration and app store packaging.

---

## Quick Start

**Prerequisites:** Flutter 3.41.9, `.env` file in this directory (already committed — contains Supabase anon key).

```powershell
cd mobile
flutter pub get
flutter run -d chrome --no-pub
# or on a fixed port:
flutter run -d web-server --web-port 8091 --no-pub
```

App opens at `http://localhost:8091`.

---

## Test Accounts

| Email | Password | Role | Dashboard |
|---|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | Super Admin | Admin Portal — full system control |
| `adam.grant824+om@gmail.com` | `TestPass123!` | Operations Manager | OM Dashboard — communities, routes, on-time % |
| `adam.grant824+pm@gmail.com` | `TestPass123!` | Property Manager | PM Dashboard — properties, requests, announcements |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | Worker / Driver | Worker Dashboard — route, stops, earnings |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | Resident | Resident Dashboard — unit 104, Sunset Gardens |

**Test property:** Sunset Gardens · **Test unit:** 104 · **Invite code:** `WELCOME104`

---

## Feature Guide by Role

### Super Admin (`relaxedlivingtx@gmail.com`)

Business owner account. Five-tab admin portal:

1. **Users** — all accounts with role pills; tap to edit role, name, email
2. **Properties** — all properties; configure service window and comeback fee
3. **Residents** — active unit assignments; filter by property
4. **Concerns** — resident-submitted concerns; filter by Open / In Review / Resolved
5. **Tools** — Invite Codes sub-screen, Comeback Requests, Worker Assignments, Sign Out

---

### Operations Manager (`adam.grant824+om@gmail.com`)

Manages the nightly operation. Five tabs:

1. **Overview** — "Operations Overview" header with Today filter; Communities and Routes counts; large On-Time % and Missed count; 7-day Service Completion % chart; tonight's runs list
2. **Routes** — per-property nightly run detail with completion status
3. **Alerts** — sent notification history
4. **Reports** — comeback request history (7 days)
5. **More** — Live Worker Map (real-time GPS), Send Notification, sign out

**To test:** Overview tab shows live metrics. More → Live Worker Map shows the worker dot when the worker account is on duty and sharing location.

---

### Property Manager (`adam.grant824+pm@gmail.com`)

Property-level oversight. Four tabs:

1. **Dashboard** — "Property Manager View" with All Properties filter; Open Requests count; Work Orders placeholder; recent community announcements list; Send Announcement button; compliance % and satisfaction score
2. **Properties** — per-property unit count, resident count, violation count, invite codes
3. **Requests** — recent nightly runs with status badges
4. **More** — Compliance Report (date range filter, CSV export), change password, sign out

**To test:** Dashboard → Send Community Announcement → residents see it in their Community Updates. More → Compliance Report → set date range → Export CSV (web download; native share sheet when built for device).

---

### Worker / Driver (`adam.grant824+worker@gmail.com`)

Field app for nightly pickup. Five tabs:

1. **Route** — "Hello [name] / You have N stops today" header; progress donut with center %; Next Stop card with unit number; Clock In / Clock Out button; Share Location; View Map
2. **Stops** — full stop list; tap to mark complete (photo optional) or flag as comeback
3. **Scan** — QR code scan (unit confirmation)
4. **Messages** — direct messages with OM (real-time)
5. **More** — Earnings screen (weekly/monthly hours from clock events); change password; sign out

**To test:** Route tab → Clock In → mark a stop complete → check OM's Live Worker Map.

---

### Resident (`adam.grant824+res2@gmail.com`)

What apartment residents see. Four tabs:

1. **Home** — "Good morning / [Property Name] ▾" header with bell icon; Next Service time + On Schedule / Active / All Clear status; Request a Comeback card (1 free/month); Rate Your Service card; Community Updates feed
2. **Services** — extra services screen
3. **Messages** — (placeholder)
4. **Profile** — vacation hold toggle; change password; sign out

**New resident signup:** Sign-in screen → "Don't have an account? Sign up" → email + invite code (`WELCOME104` for Sunset Gardens unit 104).

---

### Auth Features (all roles)

- **Forgot password:** Sign-in screen → "Forgot password?" → email → reset link → new password. Deep link: `com.relaxedliving.valet://login-callback`
- **Change password:** Profile tab on every dashboard → "Change Password" button
- **Password visibility:** Eye icon on all password fields
- **Social login:** Apple and Google OAuth on sign-in screen

---

## Getting to the App Store and Google Play

The app is feature-complete. What remains is store logistics.

### Android (Google Play)

Requires Android SDK (Android Studio or standalone).

```bash
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

The signing keystore is at `android/upload-keystore.jks`. Already wired into `android/app/build.gradle.kts` via `android/key.properties`:

```
storePassword=RLValet2026!Key
keyPassword=RLValet2026!Key
keyAlias=upload
storeFile=../upload-keystore.jks
```

**Submit to Google Play:**
1. [Google Play Console](https://play.google.com/console) → Create app
2. Store listing: title, description, screenshots, privacy policy URL
3. Upload the `.aab` under Release → Internal Testing (then promote to Production)
4. Content rating, data safety form → Submit (1–3 day review)

---

### iOS (App Store)

**Requires macOS + Xcode + Apple Developer account ($99/year).**

iOS project is fully configured — bundle ID `com.relaxedliving.valet`, privacy strings, URL scheme for deep links.

1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`)
2. Runner target → Signing & Capabilities → set your Apple Developer Team
3. Xcode provisions automatically
4. Build:
   ```bash
   flutter build ipa
   ```
5. Upload via Xcode Organizer or `xcrun altool`

**Submit to App Store Connect:**
1. [App Store Connect](https://appstoreconnect.apple.com) → New App
2. Bundle ID: `com.relaxedliving.valet`
3. Screenshots: 6.7" iPhone (required), 12.9" iPad (optional); description, keywords, age rating, privacy policy
4. Submit for review (24–48 hours)

---

### Production Supabase Config

Currently pointed at `localhost:8091` — update before going live:

1. [Supabase Dashboard](https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft) → Auth → URL Configuration
2. **Site URL** → your production domain
3. **Redirect URLs** → add production domain + keep `com.relaxedliving.valet://login-callback`
4. Auth → SMTP Settings → enable Resend or SendGrid (email confirmation is disabled in dev)

---

### Store Listing Assets

| Asset | iOS | Android |
|---|---|---|
| Screenshots | 6.7" iPhone (required), 12.9" iPad (optional) | Phone + tablet |
| App icon | 1024×1024 PNG, no alpha ✅ done | 512×512 PNG ✅ done |
| Short description | 30 chars | 80 chars |
| Full description | 4000 chars | 4000 chars |
| Privacy policy URL | Required | Required |
| Age rating | Fill questionnaire | Fill content rating |

---

## What's Not Yet Built (Next Sprint)

| Feature | Status | What's needed |
|---|---|---|
| **Stripe paid comebacks** | Placeholder UI ready | Stripe account + webhook secret → wire into `ResidentComebackRequestScreen` paid path |
| **Push notifications** | Not built | FCM (Android, free) + APNs via Apple Developer account. Defer until TestFlight / Play internal testing |
| **Worker GPS on native** | Web only | Swap `dart:html` geolocation → `geolocator` package for iOS/Android builds |
| **CSV export on native** | Web only | Swap `dart:html` download → `path_provider` + `share_plus` for iOS/Android builds |
| **Work Orders** | Placeholder (shows 0) | No `work_orders` table — add in a future sprint if needed |

---

## Supabase Project

| Item | Value |
|---|---|
| Project name | relaxed-living |
| Project ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| Dashboard | https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft |

To access the dashboard (database, auth users, storage, logs): ask to be added as a project member or have ownership transferred to your Supabase account.

---

## Android Signing Key

Keystore at `android/upload-keystore.jks` — **do not lose this file.**

- **Alias:** `upload`
- **Password:** `RLValet2026!Key`

If the keystore is ever lost, Google Play allows one keystore reset per app lifetime. Back it up to a password manager or secure drive now.
