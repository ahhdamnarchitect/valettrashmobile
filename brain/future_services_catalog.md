# Future services catalog

Add-on services that were designed into the UI but never built. Preserved here on
2026-08-20 when the placeholder screens were deleted, so the product intent survives
without dead "coming soon" code sitting in `lib/`.

Every one of these was a tile that showed a *"… coming soon!"* toast. None had a
backend, a price, or a request path.

## Resident-facing (was `resident_services_screen.dart`)

| Service | Notes |
|---|---|
| Comeback pickup | **Now built** — `ResidentComebackRequestScreen` + Stripe packs (1/$5, 3/$14, 5/$20) |
| Bulk pickup | Large items / bulk trash. Partially covered today by `service_requests` (type `Bulk`) |
| Carpet cleaning | Professional carpet cleaning |
| Maid / cleaning service | Professional home cleaning |
| Moving service | Moving and relocation |
| Power washing | |
| Pressure washing | Around trash areas |
| Cleanup | Around dumpster / compactor zones |
| Photo upload on concerns | Support form never got attachments; the violation and missed-pickup flows do have working photo upload |

## Property-manager-facing (was `manager_property_services_screen.dart`)

| Service | Notes |
|---|---|
| Power washing / sanitation | Professional power washing and sanitation |
| Dumpster area power washing | Focused washing for dumpster areas |
| Pressure washing around trash areas | High-pressure cleaning around trash zones |
| Compactor / dumpster zone cleanup | Maintenance of trash compaction areas |
| Property cleanup requests | Manage resident cleanup and maintenance requests |

## If you build these

The generic path already exists — `public.service_requests` takes a free-form
`service_type` plus a message and `preferred_time`, residents can insert their own,
and the owner tier sees them in `ServiceRequestsInboxScreen`. Adding a service is
mostly: a tile that opens `showServiceRequestSheet()` with the right `service_type`,
plus pricing if it is paid. Paid ones should follow the comeback pattern and go
through Stripe — `payment_orders` and the `stripe-webhook` function are already
wired, and credits must only ever be granted by the webhook (see migration 026).
