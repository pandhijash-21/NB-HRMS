-- Data fix: the waiting-list dispatcher used to copy the allocated telecaller into
-- "assigned_to_id" (which is reserved for the sales rep set by the Visitor Desk).
-- Clear that copy only where no site visit was ever scheduled/done and the lead
-- has not progressed into the sales stages. Allocated telecaller (telecaller_id) is untouched.
UPDATE "crm_leads"
SET "assigned_to_id" = NULL
WHERE "assigned_to_id" IS NOT NULL
  AND "telecaller_id" IS NOT NULL
  AND "assigned_to_id" = "telecaller_id"
  AND "scheduled_visit_at" IS NULL
  AND "visited_at" IS NULL
  AND "status"::text NOT IN ('SCHEDULED_VISIT', 'SITE_VISIT_DONE', 'PROPOSAL_SENT', 'BOOKING_CONFIRMED', 'REJECTED');
