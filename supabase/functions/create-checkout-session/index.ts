import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.14.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const PACKS = [
  { quantity: 1, priceCents: 500, label: "1 comeback" },
  { quantity: 3, priceCents: 1400, label: "3 comebacks" },
  { quantity: 5, priceCents: 2000, label: "5 comebacks" },
] as const;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const defaultOrigin = Deno.env.get("APP_ORIGIN") ?? "http://localhost:8091";
const allowedOrigins = (Deno.env.get("APP_ORIGINS") ?? defaultOrigin)
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }
  if (!stripeSecret || !supabaseUrl || !serviceRole) {
    return json({ error: "Stripe is not configured on the server" }, 503);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "Not signed in" }, 401);

  const admin = createClient(supabaseUrl, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userErr || !user) return json({ error: "Invalid session" }, 401);

  let body: {
    kind?: string;
    quantity?: number;
    notes?: string;
    success_origin?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const kind = body.kind === "comeback" ? "comeback" : "pack";
  const origin = allowedOrigins.includes(body.success_origin ?? "")
    ? body.success_origin!
    : defaultOrigin;

  const { data: unit, error: unitErr } = await admin
    .from("resident_units")
    .select("id, property_id")
    .eq("user_id", user.id)
    .eq("is_active", true)
    .maybeSingle();
  if (unitErr || !unit) {
    return json({ error: "No active unit assignment found" }, 400);
  }

  let quantity = 1;
  let amountCents = PACKS[0].priceCents;
  let productName = "Paid comeback pickup";

  if (kind === "pack") {
    const pack = PACKS.find((p) => p.quantity === Number(body.quantity));
    if (!pack) return json({ error: "Unknown pack" }, 400);
    quantity = pack.quantity;
    amountCents = pack.priceCents;
    productName = `Comeback pack (${pack.label})`;
  }

  const stripe = new Stripe(stripeSecret, { apiVersion: "2023-10-16" });

  let requestId: string | null = null;
  if (kind === "comeback") {
    const insertData: Record<string, unknown> = {
      resident_user_id: user.id,
      status: "pending",
      is_free: false,
      payment_status: "pending_payment",
      payment_amount_cents: amountCents,
      requested_at: new Date().toISOString(),
    };
    if (body.notes?.trim()) insertData.notes = body.notes.trim();

    const { data: request, error: reqErr } = await admin
      .from("missed_pickup_requests")
      .insert(insertData)
      .select("id")
      .single();
    if (reqErr || !request) {
      return json({ error: reqErr?.message ?? "Could not create request" }, 400);
    }
    requestId = request.id as string;
  }

  const { data: order, error: orderErr } = await admin
    .from("payment_orders")
    .insert({
      user_id: user.id,
      property_id: unit.property_id,
      resident_unit_id: unit.id,
      missed_pickup_request_id: requestId,
      kind,
      quantity,
      amount_cents: amountCents,
      status: "pending",
    })
    .select("id")
    .single();
  if (orderErr || !order) {
    return json({ error: orderErr?.message ?? "Could not create order" }, 400);
  }

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      customer_email: user.email ?? undefined,
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: "usd",
            unit_amount: amountCents,
            product_data: { name: productName },
          },
        },
      ],
      success_url: `${origin}/?checkout=success&order=${order.id}`,
      cancel_url: `${origin}/?checkout=cancel&order=${order.id}`,
      metadata: {
        order_id: order.id,
        user_id: user.id,
        kind,
        quantity: String(quantity),
      },
      client_reference_id: order.id,
    });

    await admin
      .from("payment_orders")
      .update({ stripe_checkout_session_id: session.id })
      .eq("id", order.id);

    if (requestId) {
      await admin
        .from("missed_pickup_requests")
        .update({ stripe_checkout_session_id: session.id })
        .eq("id", requestId);
    }

    return json({ url: session.url, order_id: order.id });
  } catch (e) {
    console.error("Stripe session error", e);
    return json({ error: "Could not start Stripe Checkout" }, 500);
  }
});
