-- Manual door counts for billing (when unit tree not fully built in app).

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS billing_total_doors INTEGER;

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS billing_occupied_doors INTEGER;

COMMENT ON COLUMN public.properties.billing_total_doors IS
    'Total doors/units for contract billing; falls back to counted units when null.';

COMMENT ON COLUMN public.properties.billing_occupied_doors IS
    'Occupied doors for billing; falls back to active resident_units when null.';
