-- Speed up trip route lookups (WHERE trip_id = ? ORDER BY timestamp)
CREATE INDEX IF NOT EXISTS "location_history_trip_id_timestamp_idx"
ON "location_history"("trip_id", "timestamp");
