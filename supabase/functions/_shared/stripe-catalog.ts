export type Pack = { quantity: number; priceCents: number; label: string };

export const COMEBACK_PACKS: Pack[] = [
  { quantity: 1, priceCents: 500, label: "1 comeback" },
  { quantity: 3, priceCents: 1400, label: "3 comebacks" },
  { quantity: 5, priceCents: 2000, label: "5 comebacks" },
];

export function packForQuantity(quantity: number): Pack | null {
  return COMEBACK_PACKS.find((p) => p.quantity === quantity) ?? null;
}

export const SINGLE_COMEBACK = COMEBACK_PACKS[0];

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
