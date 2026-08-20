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

### Remaining — owner action only (I can't do these)

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
