# Test Credentials

> **✅ Live on the dedicated project `immiejqvnucndjspacwv` (verified 2026-08-19).**
> All seven accounts below exist in `auth.users`, have matching `public.users` profile rows
> with the correct role, and **password sign-in was tested end-to-end against the live API**.
> Email confirmation is off (signup is gated by invite codes instead), so accounts work
> immediately. Password policy: min 8 chars, upper + lower + digit + symbol.

App runs at: `http://localhost:8091` (this PC). iPad on same Wi-Fi: `http://<PC-IPv4>:8091`. Marketing site is **https://relaxlivingvalet.com** (not the app).

---

## Business owner (Owner dashboard)

**Owner** and **super_admin** are the same login tier — both open the **Owner dashboard**.  
System setup (invite codes, users, billing tools) is **More → Admin Portal**.

| Email | Password | Role | Screen |
|---|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | `owner` | **Owner dashboard** (Financials, labor, portfolio) |
| `relaxedlivingtx+owner@gmail.com` | `RelaxedLiving2026!` | `owner` | Same (optional alias; create in Supabase Auth first — see `supabase/seed_data/013_owner_test_account.md`) |

Sign in with **Staff** (not Resident).

---

## Staff / Internal Accounts

| Email | Password | Role | Notes |
|---|---|---|---|
| `adam.grant824+om@gmail.com` | `TestPass123!` | `operations_manager` | OM Dashboard — workforce, routes, live map |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | `driver` | Worker Dashboard — clock in, route |

## Customer / Resident Accounts

| Email | Password | Role | Notes |
|---|---|---|---|
| `adam.grant824+pm@gmail.com` | `TestPass123!` | `property_manager` | PM Dashboard |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | `resident` | Sunset Gardens unit 104 |
| `adam.grant824+testres104@gmail.com` | `TestPass123!` | `resident` | Additional resident test |
| `devinbooker817@gmail.com` | *(unknown)* | `resident` | Real user |
| `powellreggie23@gmail.com` | *(unknown)* | `resident` | Real user |

## Test Data

| Item | Value |
|---|---|
| Property | Sunset Gardens, ID `10000000-0000-0000-0000-000000000001` |
| Unit | 104 |
| Invite code | `WELCOME104` |

## Role → Screen Mapping

| Role | Screen |
|---|---|
| `owner` | `OwnerDashboardScreen` (light) — **primary business owner** |
| `super_admin` | Same as `owner` (legacy enum value; use `owner` in DB for new accounts) |
| `operations_manager` | `ManagerDashboardScreen` |
| `property_manager` | `PropertyManagerDashboardNewScreen` |
| `driver` | `WorkerDashboardScreen` |
| `resident` | `ResidentDashboardScreen` |

Admin Portal (`AdminDashboardScreen`) is reached from **Owner → More → Admin Portal**, not a separate login.

## Notes

- Supabase email confirmation is **disabled** — accounts work immediately after creation.
- Password reset: "Forgot password?" on login or "Change Password" in profile tabs.
- Site URL: `http://localhost:8091` (keep for local; later add `https://relaxlivingvalet.com` as Redirect URL, do not drop localhost until the app is hosted).
- Property Manager = apartment office; Owner = Relaxed Living.
