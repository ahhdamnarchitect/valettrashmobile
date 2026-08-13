# Stripe setup — Relaxed Living Valet

Residents pay for **comeback packs** and **single paid comebacks** via Stripe Checkout.  
The Flutter app **never** holds the Stripe secret key.

## What you need first

1. LLC (done)
2. **Business bank account**
3. Stripe account under the LLC → [https://dashboard.stripe.com](https://dashboard.stripe.com)
4. Complete Stripe identity / bank verification (test mode works before that)

## 1. Database

Hosted migration `015_stripe_payments.sql` is **already applied** (`stripe_payments`).

## 2. Stripe keys (start in **Test mode**)

Dashboard → Developers → API keys:

- Secret key: `sk_test_...`
- Publishable key is **not** required for hosted Checkout

## 3. Set Edge Function secrets

Supabase Dashboard → Project **airpwzzkyjqzeeqizvft** → Edge Functions → Secrets:

| Name | Value |
|---|---|
| `STRIPE_SECRET_KEY` | `sk_test_...` (then `sk_live_...` later) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` from the webhook endpoint |
| `APP_ORIGIN` | `http://localhost:8091` |
| `APP_ORIGINS` | `http://localhost:8091` (comma-separated if you add more) |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

If you install the CLI later:

```powershell
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_KEY
supabase secrets set APP_ORIGIN=http://localhost:8091
supabase secrets set APP_ORIGINS=http://localhost:8091
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

## 4. Deploy functions

Already deployed (Aug 13):

- `create-checkout-session` — JWT **ON**
- `stripe-webhook` — JWT **OFF** (Stripe cannot send a Supabase JWT)

Redeploy after changing function code. Secrets can be set without a redeploy.

## 5. Webhook endpoint

Stripe Dashboard → Developers → Webhooks → Add endpoint:

```
https://airpwzzkyjqzeeqizvft.supabase.co/functions/v1/stripe-webhook
```

Events to send:

- `checkout.session.completed`
- `checkout.session.expired`
- `checkout.session.async_payment_failed`

Copy the signing secret (`whsec_...`) into the `STRIPE_WEBHOOK_SECRET` Edge Function secret.

Secrets take effect on the next request; no redeploy required after only changing secrets.

## 6. Test in the app

1. `flutter run -d web-server --web-port 8091 --no-pub`
2. Log in as resident (`adam.grant824+res2@gmail.com`)
3. Extra Services → buy a pack **or** request a paid comeback
4. Use Stripe test card: `4242 4242 4242 4242`, any future expiry, any CVC
5. Confirm `payment_orders.status = paid` and credits / request `payment_status = paid`

## 7. Go live later

1. Link business bank in Stripe
2. Switch to **live** keys (`sk_live_...`)
3. Update secrets
4. Create a **live** webhook endpoint (same URL, new `whsec_`)
5. Keep test and live secrets separate (staging vs prod projects)

## Security

- Never put `sk_` or `whsec_` in `mobile/.env` or GitHub
- Only `SUPABASE_ANON_KEY` in the Flutter client
- Prices are enforced server-side (1/$5, 3/$14, 5/$20)
- Credits are added **only** by the webhook after a paid session
