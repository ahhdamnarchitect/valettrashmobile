# Relaxed Living Valet — Mobile App

Flutter app for the full valet trash operation: residents, workers, property managers, operations managers, owners, and admins all have their own dashboard. This file is your guide to running the app, testing every role, and getting it into the App Store and Google Play.

---

## Quick Start

**Prerequisites:** Flutter 3.41.9 installed, `.env` file in this directory (already committed — contains Supabase credentials).

```powershell
cd C:\path\to\valettrashmobile\mobile
flutter pub get
flutter run -d chrome --no-pub
# or on a specific port:
flutter run -d web-server --web-port 8091 --no-pub
```

App opens at `http://localhost:8091`.

---

## Test Accounts

Use these to test every role. Log in at the sign-in screen with email + password.

| Email | Password | Role | What you see |
|---|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | Super Admin | Admin Portal — full system control |
| `adam.grant824+om@gmail.com` | `TestPass123!` | Operations Manager | OM Dashboard — workers, pickups, violations |
| `adam.grant824+pm@gmail.com` | `TestPass123!` | Property Manager | PM Dashboard — property reports, CSV export |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | Worker / Driver | Worker Dashboard — route, earnings, map |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | Resident | Resident Dashboard — unit 104, Sunset Gardens |

**Test property:** Sunset Gardens  
**Test unit:** 104  
**Resident invite code:** `WELCOME104`

---

## Feature Guide by Role

### Super Admin (`relaxedlivingtx@gmail.com`)

The business owner account. Five-tab admin portal:

1. **Overview** — system-wide stats: total pickups, active workers, open violations, properties served
2. **Workers** — list of all driver accounts; view individual earnings and route history
3. **Properties** — all properties in the system; pickup completion rates per property
4. **Residents** — all resident accounts across every property
5. **Invite Codes** — generate and manage invite codes for resident signup

**To test:** Log in, tap through all 5 tabs. Invite codes tab lets you create new codes for a property.

---

### Operations Manager (`adam.grant824+om@gmail.com`)

Manages the nightly operation. Dashboard tabs:

1. **Home** — tonight's pickup summary, active workers on duty
2. **Workers** — worker list with status (on route / off)
3. **Map** — real-time worker location map (requires location permission on native; web uses browser geolocation)
4. **Violations** — all reported violations with photo evidence
5. **Profile** — change password

**To test:** Log in and check the map tab. Violations tab shows any violations filed by workers.

---

### Property Manager (`adam.grant824+pm@gmail.com`)

Property-level reporting. Dashboard tabs:

1. **Overview** — completion rate, missed pickups, violations for their property
2. **Compliance Report** — filter by date range, export as CSV
3. **Activity** — pickup-by-pickup history
4. **Profile** — change password

**To test:** Compliance Report tab → set a date range → tap Export CSV. On web this downloads directly; on native it will use the share sheet.

---

### Worker / Driver (`adam.grant824+worker@gmail.com`)

Field app for nightly pickup. Tabs:

1. **Route** — tonight's unit list; tap a unit to mark pickup complete or report a missed pickup
2. **Comeback Requests** — residents who requested a second pickup attempt
3. **Map** — worker's own location broadcast (shows on OM map)
4. **Earnings** — nightly and weekly pay summary
5. **Profile** — change password

**To test:** Route tab → mark a unit complete. Check the OM dashboard map to see the worker dot move.

---

### Resident (`adam.grant824+res2@gmail.com`)

What apartment residents see. Tabs:

1. **Home** — tonight's pickup status, countdown to pickup window, last pickup confirmation
2. **Comeback Request** — request a second pickup attempt if they missed the window (1 free per month, paid after)
3. **Concerns** — submit a general concern or complaint
4. **Report Missed Pickup** — flag that a scheduled pickup didn't happen
5. **Profile** — change password

**New resident signup flow:** On the sign-in screen, tap "Create account" → enter email + invite code (`WELCOME104` for Sunset Gardens unit 104) → account is created and auto-linked to the property.

---

### Auth Features (all roles)

- **Forgot password:** On the sign-in screen, tap "Forgot password?" → enter email → receive reset link → tap link → set new password. Works on web and mobile (deep link: `com.relaxedliving.valet://login-callback`).
- **Change password:** Every dashboard has a "Change Password" button in the Profile tab. Sends a reset email — same flow as above.
- **Password visibility:** Eye icon on all password fields to show/hide.

---

## Getting to the App Store and Google Play

This is the checklist of what's left before submission. The app is feature-complete — what remains is app store logistics.

### Step 1 — Replace the App Icon

The current icon is a placeholder (green circle with "RL"). You need a final 1024×1024 PNG with no alpha channel.

1. Drop your final icon at `assets/icon/app_icon.png` (overwrite the placeholder)
2. Drop a foreground-only version (white logo, transparent background) at `assets/icon/app_icon_foreground.png`
3. Run:
   ```powershell
   flutter pub run flutter_launcher_icons
   flutter pub run flutter_native_splash:create
   ```
4. This regenerates all Android mipmap sizes, the iOS icon set, and the splash screens automatically.

---

### Step 2 — Android (Google Play)

**Build the release bundle:**

Requires Android SDK installed (Android Studio or standalone SDK).

```bash
flutter build appbundle
```

Output: `build/app/outputs/bundle/release/app-release.aab`

The signing keystore is at `android/upload-keystore.jks`. The signing config is already wired into `android/app/build.gradle.kts` — it reads credentials from `android/key.properties`:

```
storePassword=RLValet2026!Key
keyPassword=RLValet2026!Key
keyAlias=upload
storeFile=../upload-keystore.jks
```

**If `key.properties` doesn't exist** (e.g., fresh clone), create it from the template:
```powershell
copy android\key.properties.template android\key.properties
# then fill in the real values above
```

**Submit to Google Play:**
1. Go to [Google Play Console](https://play.google.com/console) → Create app
2. Fill in store listing: title, description, screenshots (multiple densities), privacy policy URL
3. Upload the `.aab` under Release → Production (or start with Internal Testing)
4. Set content rating, target audience, data safety form
5. Submit for review (typically 1–3 days)

---

### Step 3 — iOS (App Store)

**Requires macOS + Xcode + Apple Developer account ($99/year).**

The iOS project is fully configured (`ios/Runner/Info.plist`, bundle ID `com.relaxedliving.valet`, privacy usage strings, URL scheme for deep links). You just need to sign it.

1. Open `ios/Runner.xcworkspace` in Xcode (not `.xcodeproj`)
2. Select the Runner target → Signing & Capabilities
3. Set your Apple Developer Team
4. Xcode will provision the app automatically
5. Build the IPA:
   ```bash
   flutter build ipa
   ```
6. Upload via Xcode Organizer or `xcrun altool`

**Submit to App Store Connect:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com) → New App
2. Bundle ID: `com.relaxedliving.valet`
3. Fill store listing: screenshots (6.7" iPhone required, 12.9" iPad optional), description, keywords, age rating, privacy policy URL
4. Submit for review (typically 24–48 hours)

---

### Step 4 — Production Supabase Config

Right now the Supabase project is pointed at `localhost:8091` for auth redirects — fine for development, wrong for production.

When you have a real domain or TestFlight/Play Store internal URL:

1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft) → Auth → URL Configuration
2. Update **Site URL** from `http://localhost:8091` to your production URL
3. Add your production URL to **Redirect URLs**
4. Enable a real email provider (Resend or SendGrid) under Auth → SMTP Settings — right now email confirmation is disabled and password reset emails go through Supabase's default sender (limited rate)

---

### Step 5 — App Store / Play Store Listing Assets Needed

| Asset | iOS | Android |
|---|---|---|
| Screenshots | 6.7" iPhone (required), 12.9" iPad (optional) | Phone + 7" tablet + 10" tablet |
| App icon | 1024×1024 PNG, no alpha | 512×512 PNG |
| Short description | 30 chars | 80 chars |
| Full description | 4000 chars | 4000 chars |
| Privacy policy URL | Required | Required |
| Keywords | 100 chars total | N/A (use description) |
| Age rating | Fill questionnaire | Fill content rating |

---

## What's Not Yet Built (Future Features)

These are wired up as placeholder UI but not fully functional:

- **Stripe payments** — in-app purchase for paid comeback requests (beyond the 1 free/month). Needs Stripe account + webhook secret.
- **Push notifications** — FCM for Android, APNs for iOS. Defer until the app is in TestFlight / Play internal testing so you have a real device token.
- **Worker GPS on native** — the map currently uses browser geolocation (web only). For native iOS/Android, swap to the `geolocator` package.
- **CSV export on native** — the PM compliance report export uses a web-only download method. For native, swap to `path_provider` + `share_plus`.

---

## Supabase Project

| Item | Value |
|---|---|
| Project name | relaxed-living |
| Project ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| Dashboard | https://supabase.com/dashboard/project/airpwzzkyjqzeeqizvft |

To access the Supabase dashboard (database, auth users, storage, logs), you need to be added to the Supabase project or have the project transferred to your account. Ask the previous developer to add you as a project member or transfer ownership.

---

## Android Signing Key

The release keystore is at `android/upload-keystore.jks`.

- **Alias:** `upload`
- **Password:** `RLValet2026!Key`
- **Do not lose this file.** If you lose the upload keystore, Google Play allows one keystore reset per app lifetime — contact Play support. Back it up to a password manager or secure drive.
