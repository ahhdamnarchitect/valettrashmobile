-- Per-property contract billing: fee per door + 85% minimum billable occupancy.

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS monthly_fee_per_door DECIMAL(10, 2) NOT NULL DEFAULT 25.00;

ALTER TABLE public.properties
    ADD COLUMN IF NOT EXISTS minimum_billable_occupancy_percent DECIMAL(5, 4) NOT NULL DEFAULT 0.8500;

COMMENT ON COLUMN public.properties.monthly_fee_per_door IS
    'Monthly amount billed per billable door (property manager contract).';

COMMENT ON COLUMN public.properties.minimum_billable_occupancy_percent IS
    'Minimum share of total units billed even if fewer residents are active (e.g. 0.85 = 85%).';
