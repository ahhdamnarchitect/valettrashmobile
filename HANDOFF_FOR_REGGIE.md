# Finishing the app — a step-by-step guide

**Who this is for:** Reggie. You don't need to write any code. Every step below is
signing up for something, copying a value, and pasting it into a web page.

**Where things stand:** the app is built, tested and secure. It runs today on a
computer. What's left is connecting it to three outside services — **payments**,
**email**, and **Apple** — because those need your name, your card and your accounts.
Nobody else can create them for you.

**Total cost:** about **$124 to start**, then ~$25–45/month once you have customers.
**Total time:** roughly **3–4 hours**, spread over a few days (Apple takes 24–48 hours
to approve you).

---

## Do them in this order

| # | Step | Cost | Time | Why now |
|---|---|---|---|---|
| 1 | Merge the finished work | free | 5 min | Everything else builds on it |
| 2 | Connect Stripe (payments) | free to set up | 45 min | Residents can't buy pickups without it |
| 3 | Connect email | free–$20/mo | 30 min | Password resets barely work without it |
| 4 | Join Apple Developer | **$99/year** | 30 min + 1–2 day wait | Needed to put the app on iPhones |
| 5 | Test on a real phone | free | 45 min | Catches anything the computer can't |

Start step 4 **early** — the waiting is the slow part, and you can do 2 and 3 while
Apple reviews you.

---

## Step 1 — Merge the finished work  *(5 minutes, free)*

All the recent work is sitting in a "pull request" — a pile of changes waiting for
approval. Nothing is live until it's merged.

1. Open **https://github.com/ahhdamnarchitect/valettrashmobile/pull/1**
2. Click the green **Merge pull request** button, then **Confirm merge**.

✅ **Done when:** the page says *"Merged"* in purple.

> Not sure? Ask Adam to do this one. It's the only step where a wrong click is
> annoying to undo.

---

## Step 2 — Connect Stripe so people can pay  *(45 minutes, free to set up)*

Stripe handles the card payments for extra pickups ($5 / $14 / $20 packs). Stripe
takes about 2.9% + 30¢ per payment; there's no monthly fee.

### 2a. Get your two keys

1. Go to **https://dashboard.stripe.com** and sign in (or create the business account).
2. Top-right, make sure the **Test mode** toggle is **ON** while we're testing.
3. Left sidebar → **Developers** → **API keys**.
4. Find **Secret key**, click **Reveal test key**, and copy it.
   It starts with `sk_test_`.

📋 Paste it somewhere safe for a moment — you'll need it in 2c.

> ⚠️ The secret key is like your bank password. Never email it, never text it, never
> put it in a document you share. Paste it only into the Supabase page in step 2c.

### 2b. Tell Stripe where to send payment confirmations

1. Still in Stripe: **Developers** → **Webhooks** → **Add endpoint**.
2. In **Endpoint URL**, paste exactly:
   ```
   https://immiejqvnucndjspacwv.supabase.co/functions/v1/stripe-webhook
   ```
3. Click **Select events**, search for and tick **`checkout.session.completed`**.
4. Click **Add endpoint**.
5. On the page that appears, find **Signing secret** → **Reveal**. Copy it.
   It starts with `whsec_`.

📋 You now have two values: one starting `sk_test_`, one starting `whsec_`.

### 2c. Give both keys to the app

1. Go to **https://supabase.com/dashboard/project/immiejqvnucndjspacwv/settings/functions**
2. Find the **Edge Function Secrets** section. Add three secrets, one at a time —
   click **Add new secret** for each:

   | Name (type exactly) | Value |
   |---|---|
   | `STRIPE_SECRET_KEY` | the `sk_test_…` key from 2a |
   | `STRIPE_WEBHOOK_SECRET` | the `whsec_…` key from 2b |
   | `APP_ORIGIN` | `http://localhost:8091` |

3. Click **Save**.

✅ **Done when:** all three names appear in the list. (You won't be able to see the
values again — that's normal and correct.)

### 2d. Check it worked

Ask Adam to run this one command and send you the result:
```
./scripts/go-live-check.sh stripe
```
You want to see **PASS**, not TODO, next to the webhook line.

> **Going live for real:** when you're ready to take actual money, flip Stripe's
> **Test mode** toggle OFF, redo 2a and 2b to get the *live* keys (they start
> `sk_live_` and a new `whsec_`), and replace those two secrets. Do this only after a
> test purchase has worked.

---

## Step 3 — Make password-reset emails work  *(30 minutes, free to start)*

Right now the app can only send **2–3 emails per hour** — that's Supabase's built-in
limit for testing. With real residents, most "I forgot my password" emails would never
arrive.

**Recommended: Resend** — free for 3,000 emails/month, which is plenty to start.

1. Go to **https://resend.com** and sign up.
2. Click **Domains** → **Add Domain** → enter `relaxlivingvalet.com`.
3. Resend shows you a few DNS records. These go wherever you bought the domain
   (GoDaddy, Namecheap, etc.), under "DNS settings".
   **This is the fiddly bit — if you're unsure, send Adam a screenshot of the records
   and where you buy your domain, and he'll walk you through it.**
4. Once the domain shows **Verified**, go to **API Keys** → **Create API Key**. Copy it.
5. Go to **https://supabase.com/dashboard/project/immiejqvnucndjspacwv/settings/auth**
6. Scroll to **SMTP Settings**, turn on **Enable Custom SMTP**, and fill in:

   | Field | Value |
   |---|---|
   | Host | `smtp.resend.com` |
   | Port | `465` |
   | Username | `resend` |
   | Password | the API key from step 4 |
   | Sender email | `noreply@relaxlivingvalet.com` |
   | Sender name | `Relaxed Living Valet` |

7. Click **Save**.

✅ **Done when:** you can tap "Forgot password?" in the app, and the email actually
lands in your inbox within a minute.

---

## Step 4 — Join the Apple Developer Program  *(30 min + 1–2 day wait, $99/year)*

You need this to put the app on any iPhone or iPad — including your own, and including
the in-person demo. There's no way around it and no free alternative.

1. Go to **https://developer.apple.com/programs/enroll/**
2. Sign in with your Apple ID (or make one).
3. Choose **Organization** if the business is an LLC — you'll need your **EIN**.
   Choose **Individual** if it's just you (faster, less paperwork).
4. Pay the **$99**.
5. **Wait.** Apple usually approves in 24–48 hours. Organization can take a week.

✅ **Done when:** Apple emails you saying your membership is active.

Then tell Adam — he'll build the app and send it to your phone through TestFlight
(Apple's app for testing apps before they're public).

> **Android is separate** and costs **$25 once, forever**, at
> **https://play.google.com/console/signup**. Worth doing too, but not urgent.

---

## Step 5 — Test on a real phone  *(45 minutes, free)*

Once Adam sends you the TestFlight invite, install it and try these. They're the
things a computer genuinely can't check:

- [ ] Log in as each of the six roles (Adam has the passwords)
- [ ] **Tap "Export CSV"** on the Owner → Financials screen. The share sheet should
      open. *(This one broke on iPad until recently — worth checking on an iPad
      specifically if you'll demo on one.)*
- [ ] As a worker: **Clock In**, then **Share location**. Allow the permission prompt.
- [ ] As a worker: take a photo when reporting a violation, confirm it saves.
- [ ] As a resident: **Forgot password?** → check the email arrives → reset it → make
      sure tapping the link opens the app.
- [ ] Buy a $5 pickup pack using Stripe's test card: **4242 4242 4242 4242**,
      any future expiry, any 3-digit code. Confirm the credit appears.

Anything that misbehaves — screenshot it and send it to Adam.

---

## Two smaller things (ask Adam, 5 minutes)

- **Do NOT connect GitHub to the database yet.** This was on an earlier version of
  this list and it was wrong — connecting it now would break things. The database
  already has everything it needs; the connection is a convenience for *future*
  updates, and setting it up safely takes real work (renaming 36 files and telling
  Supabase what's already been applied). Adam has written down why. Leave it alone.
- **The old Supabase project has security holes** that were fixed in the new one. If
  you're not using it any more, delete it. If you are, tell Adam so he can patch it.

---

## Quick reference

| What | Where |
|---|---|
| The code | https://github.com/ahhdamnarchitect/valettrashmobile |
| Database & settings | https://supabase.com/dashboard/project/immiejqvnucndjspacwv |
| Payments | https://dashboard.stripe.com |
| Email | https://resend.com |
| Apple | https://developer.apple.com |

**Health check** — Adam can run `./scripts/go-live-check.sh` at any point. It prints
PASS / FAIL / TODO for every item above, so you can always see exactly what's left
without guessing.

---

## If you only remember one thing

**Never paste a key that starts with `sk_` into an email, a text, or a shared
document.** Those keys can move real money. They belong in exactly one place: the
Supabase settings page in step 2c. Everything else in this guide is safe to get wrong
and retry.
