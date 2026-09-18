-- AlterTable
ALTER TABLE "attendance_policy" ADD COLUMN IF NOT EXISTS "max_buffer_days_per_month" INTEGER NOT NULL DEFAULT 2;

-- CreateTable
CREATE TABLE IF NOT EXISTS "attendance_policy_day_overrides" (
    "id" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "default_punch_in_time" TEXT,
    "default_punch_out_time" TEXT,
    "punch_in_buffer_minutes" INTEGER,
    "punch_out_buffer_minutes" INTEGER,
    "note" TEXT,
    "updated_by" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attendance_policy_day_overrides_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "attendance_policy_day_overrides_date_key" ON "attendance_policy_day_overrides"("date");
