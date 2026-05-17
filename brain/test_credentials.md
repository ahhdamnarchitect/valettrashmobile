# Test Credentials

All accounts are in the Supabase project `airpwzzkyjqzeeqizvft` (relaxed-living, AWS us-east-2).

App runs at: `http://localhost:8091`

---

## Staff / Internal Accounts

| Email | Password | Role | Notes |
|---|---|---|---|
| `relaxedlivingtx@gmail.com` | `RelaxedLiving2026!` | `super_admin` | Business owner — lands on Admin Portal (5-tab dashboard) |
| `adam.grant824+om@gmail.com` | `TestPass123!` | `operations_manager` | Test Ops Manager — lands on OM Dashboard |
| `adam.grant824+worker@gmail.com` | `TestPass123!` | `driver` | Test Worker — lands on Worker Dashboard |

## Customer / Resident Accounts

| Email | Password | Role | Notes |
|---|---|---|---|
| `adam.grant824+pm@gmail.com` | `TestPass123!` | `property_manager` | Test Property Manager — lands on PM Dashboard |
| `adam.grant824+res2@gmail.com` | `TestPass123!` | `resident` | Test Resident — unit 104, Sunset Gardens |
| `adam.grant824+testres104@gmail.com` | `TestPass123!` | `resident` | Additional resident test account |
| `devinbooker817@gmail.com` | *(unknown — real user)* | `resident` | Real user via resident signup flow |
| `powellreggie23@gmail.com` | *(unknown — real user)* | `resident` | Real user via resident signup flow |

## Test Data

| Item | Value |
|---|---|
| Property | Sunset Gardens, ID `10000000-0000-0000-0000-000000000001` |
| Unit | 104 |
| Invite code | `WELCOME104` |

## Role → Screen Mapping

| Role | Screen |
|---|---|
| `super_admin` | `AdminDashboardScreen` (light theme) |
| `operations_manager` | `ManagerDashboardScreen` |
| `property_manager` | `PropertyManagerDashboardNewScreen` |
| `driver` | `WorkerDashboardScreen` |
| `resident` | `ResidentDashboardScreen` |
| `owner` | `OwnerDashboardScreen` (light theme) |

## Notes

- Supabase email confirmation is **disabled** — accounts work immediately after creation.
- To promote any account to super_admin temporarily for admin portal testing:
  ```sql
  UPDATE users SET role='super_admin' WHERE email='adam.grant824+om@gmail.com';
  -- restore with:
  UPDATE users SET role='operations_manager' WHERE email='adam.grant824+om@gmail.com';
  ```
- Password reset flow: "Forgot password?" on login screen or "Change Password" in any profile tab → sends reset email → user clicks link → lands on Set New Password form.
- Supabase Auth → URL Configuration: Site URL = `http://localhost:8091`, Redirect URL = `http://localhost:8091` (update both when deploying to production).
