import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }
  if (!stripeSecret || !webhookSecret || !supabaseUrl || !serviceRole) {
    console.error("Missing Stripe or Supabase secrets");
    return new Response("Server not configured", { status: 503 });
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: "2023-10-16" });
  const body = await req.text();
  const sig = req.headers.get("stripe-signature");
  if (!sig) return new Response("No signature", { status: 400 });

  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, webhookSecret);
  } catch (e) {
    console.error("Webhook signature verification failed:", e);
    return new Response("Bad signature", { status: 400 });
  }

  const admin = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    switch (event.type) {
      case "checkout.session.completed": {
        const session = event.data.object as Stripe.Checkout.Session;
        await fulfillCheckout(admin, session);
        break;
      }
      case "checkout.session.expired":
      case "checkout.session.async_payment_failed": {
        const session = event.data.object as Stripe.Checkout.Session;
        await markOrder(admin, session.id, "canceled");
        break;
      }
      default:
        console.log("Unhandled event:", event.type);
    }
  } catch (e) {
    console.error("Webhook handler error", e);
    return new Response("Handler error", { status: 500 });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});

async function markOrder(
  admin: ReturnType<typeof createClient>,
  sessionId: string,
  status: string,
) {
  await admin
    .from("payment_orders")
    .update({ status })
    .eq("stripe_checkout_session_id", sessionId)
    .eq("status", "pending");
}

async function fulfillCheckout(
  admin: ReturnType<typeof createClient>,
  session: Stripe.Checkout.Session,
) {
  if (session.payment_status !== "paid" && session.status !== "complete") {
    console.log("Session not paid", session.id, session.payment_status);
    return;
  }

  const { data: order, error } = await admin
    .from("payment_orders")
    .select(
      "id, user_id, property_id, resident_unit_id, missed_pickup_request_id, kind, quantity, amount_cents, status",
    )
    .eq("stripe_checkout_session_id", session.id)
    .maybeSingle();

  if (error || !order) {
    console.error("Order not found for session", session.id, error);
    return;
  }
  if (order.status === "paid") return;

  const paidAt = new Date().toISOString();
  const intentId =
    typeof session.payment_intent === "string"
      ? session.payment_intent
      : session.payment_intent?.id ?? null;

  await admin
    .from("payment_orders")
    .update({
      status: "paid",
      paid_at: paidAt,
      stripe_payment_intent_id: intentId,
    })
    .eq("id", order.id);

  if (order.kind === "pack" && order.resident_unit_id) {
    const { data: unit } = await admin
      .from("resident_units")
      .select("purchased_comeback_balance")
      .eq("id", order.resident_unit_id)
      .maybeSingle();
    const current = (unit?.purchased_comeback_balance as number | null) ?? 0;
    await admin
      .from("resident_units")
      .update({
        purchased_comeback_balance: current + (order.quantity as number),
      })
      .eq("id", order.resident_unit_id);
  }

  if (order.kind === "comeback" && order.missed_pickup_request_id) {
    await admin
      .from("missed_pickup_requests")
      .update({
        payment_status: "paid",
        stripe_payment_intent_id: intentId,
      })
      .eq("id", order.missed_pickup_request_id);
  }

  if (order.property_id) {
    await admin.from("invoices").insert({
      resident_user_id: order.user_id,
      property_id: order.property_id,
      stripe_invoice_id: session.id,
      amount: (order.amount_cents as number) / 100,
      description: order.kind === "pack"
        ? `Comeback pack x${order.quantity}`
        : "Paid comeback pickup",
      due_date: paidAt.slice(0, 10),
      paid_at: paidAt,
      status: "paid",
    });
  }
}
