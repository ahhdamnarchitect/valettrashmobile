# Current State

## Current Objective
**App Store / Play Store ready.** All features complete. Native Android and iOS platform directories generated and configured. Waiting on final icon artwork and Apple Developer account before actual submission.

## Run the App
```powershell
cd C:\Users\e159305\Projects\valettrashmobile\mobile
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" run -d web-server --web-port 8091 --no-pub
# or
& "C:\Users\e159305\Apps\flutter\bin\flutter.bat" run -d chrome --no-pub
```

---

## Supabase

| Item | Value |
|---|---|
| Project | `relaxedl-living` |
| Ref | `airpwzzkyjqzeeqizvft` |
| Region | AWS us-east-2 |
| Site URL | `http://localhost:8091` |
| Redirect URLs | `http://localhost:8091`, `com.relaxedliving.valet://login-callback` |

- All tables migrated, RLS enabled, SECURITY DEFINER RPCs in place
- `violations` storage bucket with RLS policies
- Seed data: property `10000000-0000-0000-0000-000000000001` (Sunset Gardens), unit 104, invite code `WELCOME104`
- Email confirmation **disabled** — re-enable when a real email provider is configured

---

## Flutter App (`mobile/`)

- **Package name**: `valet` (renamed from `mobile` in session 10)
- **Flutter SDK**: `C:\Users\e159305\Apps\flutter\bin` (Flutter 3.41.9)
- **Entry**: `main.dart` → `ValetApp` → `AuthGate` → `RoleHome` switch → role dashboard

### Role → Screen Routing

| Role | Screen | Theme |
|---|---|---|
| `resident` | `ResidentDashboardScreen` | Dark |
| `driver` | `WorkerDashboardScreen` | Dark |
| `operations_manager` | `ManagerDashboardScreen` | Dark |
| `property_manager` | `PropertyManagerDashboardNewScreen` | Light |
| `owner` | `OwnerDashboardScreen` | Light |
| `super_admin` | `AdminDashboardScreen` | Light |

### Auth Flow
- `AuthGate` (StreamBuilder on `onAuthStateChange`) intercepts `passwordRecovery` event → shows `ChangePasswordScreen(isRecovery: true)`
- Login screen has "Forgot password?" link (below password field, login mode only)
- All dashboards have a "Change Password" button in profile/settings tab
- `Supabase.initialize()` has `authCallbackUrlHostname: 'login-callback'` for mobile deep links

### Design System
- Tokens: `core/theme/app_colors.dart` — background, surface1/2, border, textPrimary/Secondary/Muted
- Role accents: resident=emerald, worker=amber, manager=indigo, owner=purple, admin=info
- Shared widgets: `GlowBadge`, `StatTile`, `SkeletonCard`, `RoleHeroCard`, `PrimaryButton`, `RoleBottomNav`
- Animations: `SharedAxisPageRoute` (`core/utils/page_transitions.dart`), Lottie success/error

### Key Technical Gotchas
- Supabase v1 filter: `.filter('col', 'in', '(${ids.join(',')})')` — not `.inFilter()`
- `Future.wait(<Future<dynamic>>[...])` — typed generic required for Flutter web
- `GlowBadge` requires `accent` (required) and `showDot` (optional, default true)
- `supabase.auth.updateUser()` not `.update()` (gotrue-1.12.6 API)
- Password reset on mobile passes `redirectTo: 'com.relaxedliving.valet://login-callback'`; web passes `null`

---

## Native Platform (Android + iOS)

Generated in session 10. Both platforms use bundle ID `com.relaxedliving.valet`.

### Android
- `applicationId`: `com.relaxedliving.valet`
- `minSdk`: 21
- Permissions: INTERNET, CAMERA, READ_MEDIA_IMAGES, READ/WRITE_EXTERNAL_STORAGE, ACCESS_FINE/COARSE_LOCATION
- Release signing: `android/upload-keystore.jks` + `android/key.properties` (password: `RLValet2026!Key`)
- R8 minification + resource shrinking enabled in release builds
- Deep link intent filter: `com.relaxedliving.valet://login-callback`

### iOS
- Bundle ID set via Xcode (`PRODUCT_BUNDLE_IDENTIFIER` = `com.relaxedliving.valet`)
- Display name: "Relaxed Living Valet"
- Privacy strings: Camera, Photo Library (read + add), Location when in use
- URL scheme: `com.relaxedliving.valet` (for deep links)
- Portrait-only on phones; all orientations on iPad
- **iOS builds require macOS + Xcode + Apple Developer account**

### App Icon & Splash
- Placeholder icon at `assets/icon/app_icon.png` — emerald circle with "RL" monogram
- Generated with `flutter pub run flutter_launcher_icons` (all Android mipmap sizes + adaptive, all iOS sizes)
- Splash: dark `#0A0C0F` background, Android 12+ compatible
- Generated with `flutter pub run flutter_native_splash:create`
- **Replace placeholder before submitting** — drop final 1024×1024 PNG into `assets/icon/app_icon.png` and re-run launcher icons

---

## Test Accounts
Full list in `brain/test_credentials.md`. Quick reference:

| Email | Password | Role |
|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | `super_admin` |
| `adam.grant824+om@gmail.com` | `TestPass123!` | `operations_manager` |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | `driver` |
| `adam.grant824+pm@gmail.com` | `TestPass123!` | `property_manager` |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | `resident` (unit 104) |

---

## Known Issues / Constraints
- `supabase_flutter` pinned at v1.10.25 — v2 upgrade blocked by missing transitive deps in this environment; try on a machine with full internet access
- `.env` is not committed — developers need `mobile/.env` with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- `withOpacity` deprecation warnings (info only, not errors) — use `.withValues(alpha: ...)` to silence
- `PmComplianceReportScreen` uses `dart:html` for CSV export — web only; will need `dart:io` path for native builds
- Worker location sharing uses `dart:html` geolocation — web only; needs `geolocator` package for native
