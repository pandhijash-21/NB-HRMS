-- Create trips table + link location_history.trip_id (hosting / live tracking)

CREATE TABLE IF NOT EXISTS "trips" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "start_location_id" TEXT,
    "end_location_id" TEXT,
    "start_time" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "end_time" TIMESTAMP(3),
    "distance_km" DOUBLE PRECISION NOT NULL DEFAULT 0,
    CONSTRAINT "trips_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "trips_employee_id_start_time_idx" ON "trips"("employee_id", "start_time");

DO $$ BEGIN
  ALTER TABLE "trips"
    ADD CONSTRAINT "trips_employee_id_fkey"
    FOREIGN KEY ("employee_id") REFERENCES "employees"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "location_history" ADD COLUMN IF NOT EXISTS "trip_id" TEXT;

DO $$ BEGIN
  ALTER TABLE "location_history"
    ADD CONSTRAINT "location_history_trip_id_fkey"
    FOREIGN KEY ("trip_id") REFERENCES "trips"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
