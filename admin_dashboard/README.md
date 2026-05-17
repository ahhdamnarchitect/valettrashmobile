# Relaxed Living Valet — Admin dashboard

Minimal Vite + React + TypeScript console to browse **properties** and **users** using the Supabase anon key and your own login. Data visibility follows **Row Level Security** (sign in as `super_admin` or an allowed `property_manager`).

## Setup

```bash
cp .env.example .env
# edit .env — same project URL + anon key as the mobile app
npm install
npm run dev
```

Build for static hosting (e.g. Vercel): `npm run build`

## Notes

- Creating invite codes and off-cycle DB changes should use the **Supabase SQL editor** (service role) or future admin-only RPCs.
- Stripe webhooks run in `supabase/functions/stripe-webhook` — deploy with the Supabase CLI and set `STRIPE_SECRET_KEY` + `STRIPE_WEBHOOK_SECRET`.
