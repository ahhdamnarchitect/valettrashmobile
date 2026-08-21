-- PROVISION PART 6 - tidy the demo activity rows into presentable copy.
-- Run last. Idempotent. Safe to skip if you want an empty demo.
--
-- The audit created a violation, a service request, a concern, a rating, a clock
-- event and a notification while exercising each role's write path. Leaving them in
-- makes the dashboards look alive instead of empty, but the placeholder text needs
-- to read like real activity.

UPDATE public.violations
SET description = 'Bags left untied at the door. Please tie bags before setting out.'
WHERE description IN ('audit test', 'test');

UPDATE public.service_requests
SET message = 'Need a bulk pickup for a small bookshelf this week.',
    service_type = 'Bulk'
WHERE message IN ('test', 'audit test');

UPDATE public.resident_concerns
SET message = 'Hallway bin area could use an extra pass on weekends.'
WHERE message IN ('test concern', 'test');

UPDATE public.notifications
SET title = 'Valet team on site',
    message = 'Your building is being serviced this evening between 6-10pm.'
WHERE title = 'Team arrived';

SELECT
  (SELECT count(*) FROM public.violations)          AS violations,
  (SELECT count(*) FROM public.service_requests)    AS service_requests,
  (SELECT count(*) FROM public.resident_concerns)   AS concerns,
  (SELECT count(*) FROM public.satisfaction_ratings) AS ratings,
  (SELECT count(*) FROM public.clock_events)        AS clock_events,
  (SELECT count(*) FROM public.notifications)       AS notifications;
