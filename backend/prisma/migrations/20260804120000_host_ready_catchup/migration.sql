-- Catch-up for schema fields used by app but missing from older migrations.
-- Defensive: only alter tables that already exist (fresh Neon may lag mid-history).

CREATE TABLE IF NOT EXISTS "location_history" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "heading" DOUBLE PRECISION,
    "timestamp" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "location_history_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "location_history_employee_id_timestamp_idx"
  ON "location_history"("employee_id", "timestamp");

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'employees')
     AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'location_history') THEN
    BEGIN
      ALTER TABLE "location_history"
        ADD CONSTRAINT "location_history_employee_id_fkey"
        FOREIGN KEY ("employee_id") REFERENCES "employees"("id")
        ON DELETE CASCADE ON UPDATE CASCADE;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'attendance_punches') THEN
    ALTER TABLE "attendance_punches" ADD COLUMN IF NOT EXISTS "reason" TEXT;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'employee_general_info') THEN
    ALTER TABLE "employee_general_info" ADD COLUMN IF NOT EXISTS "weekly_off_days" TEXT[] DEFAULT ARRAY['SUN']::TEXT[];
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'leave_types') THEN
    ALTER TABLE "leave_types" ADD COLUMN IF NOT EXISTS "cuts_salary" BOOLEAN NOT NULL DEFAULT false;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'employee_attendance_settings') THEN
    ALTER TABLE "employee_attendance_settings" ADD COLUMN IF NOT EXISTS "biometric_token" TEXT;
  END IF;
END $$;
