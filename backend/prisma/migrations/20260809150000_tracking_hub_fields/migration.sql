-- Tracking Hub: trip analytics columns + tracking_events

ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "route_geometry" TEXT;
ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "active_time" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "idle_time" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "tracking_uptime_percent" DOUBLE PRECISION NOT NULL DEFAULT 100.0;
ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "gap_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "trips" ADD COLUMN IF NOT EXISTS "total_gap_duration" INTEGER NOT NULL DEFAULT 0;

DO $$ BEGIN
  CREATE TYPE "TrackingEventSource" AS ENUM ('EXPLICIT_EVENT', 'INFERRED_FROM_HEARTBEAT_GAP');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "TrackingEventConfidence" AS ENUM ('HIGH', 'MEDIUM', 'LOW');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "TrackingEventType" AS ENUM (
    'LOCATION_PERMISSION_REVOKED',
    'LOCATION_SERVICE_DISABLED',
    'BACKGROUND_SERVICE_KILLED',
    'GPS_SIGNAL_LOST',
    'NETWORK_UNAVAILABLE',
    'APP_FORCE_CLOSED',
    'DEVICE_RESTARTED',
    'BATTERY_DIED',
    'MANUAL_PAUSE'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "tracking_events" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "trip_id" TEXT,
    "event_type" "TrackingEventType" NOT NULL,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "end_time" TIMESTAMP(3),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "accuracy" DOUBLE PRECISION,
    "battery_level" DOUBLE PRECISION,
    "network_status" TEXT,
    "source" "TrackingEventSource" NOT NULL,
    "confidence" "TrackingEventConfidence" NOT NULL,
    "gap_reason_id" TEXT,
    CONSTRAINT "tracking_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "tracking_events_employee_id_timestamp_idx" ON "tracking_events"("employee_id", "timestamp");
CREATE INDEX IF NOT EXISTS "tracking_events_trip_id_timestamp_idx" ON "tracking_events"("trip_id", "timestamp");

DO $$ BEGIN
  ALTER TABLE "tracking_events"
    ADD CONSTRAINT "tracking_events_employee_id_fkey"
    FOREIGN KEY ("employee_id") REFERENCES "employees"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE "tracking_events"
    ADD CONSTRAINT "tracking_events_trip_id_fkey"
    FOREIGN KEY ("trip_id") REFERENCES "trips"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
