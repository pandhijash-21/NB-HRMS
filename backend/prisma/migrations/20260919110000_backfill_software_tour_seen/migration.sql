-- Existing accounts already past first-login must not see Mr NB welcome again.
UPDATE "users"
SET "software_tour_seen_at" = COALESCE("software_tour_seen_at", NOW())
WHERE "software_tour_seen_at" IS NULL
  AND "is_first_login" = false;
