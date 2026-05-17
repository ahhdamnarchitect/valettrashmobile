// Stripe webhook — verify signature and handle events (extend for subscriptions/invoices).
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";

const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  if (!stripeSecret || !webhookSecret) {
    console.error("Missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET");
    return new Response("Server not configured", { status: 503 });
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: "2023-10-16" });
  const body = await req.text();
  const sig = req.headers.get("stripe-signature");
  if (!sig) {
    return new Response("No signature", { status: 400 });
  }

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, webhookSecret);
  } catch (e) {
    console.error("Webhook signature verification failed:", e);
    return new Response("Bad signature", { status: 400 });
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      console.log(
        "checkout.session.completed",
        session.id,
        session.customer,
        session.payment_status,
      );
      // TODO: persist to subscriptions / invoices via service role or RPC
      break;
    }
    case "invoice.paid":
    case "invoice.payment_failed": {
      const inv = event.data.object as Stripe.Invoice;
      console.log(event.type, inv.id, inv.status);
      break;
    }
    default:
      console.log("Unhandled event:", event.type);
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
