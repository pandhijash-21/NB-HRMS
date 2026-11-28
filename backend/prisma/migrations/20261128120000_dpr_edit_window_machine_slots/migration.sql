-- Machine time slots on DPR machinery lines
ALTER TABLE "erp_dpr_machine_lines" ADD COLUMN IF NOT EXISTS "time_slots" JSONB;

-- Admin-configurable DPR edit window (days after report date)
CREATE TABLE IF NOT EXISTS "erp_dpr_settings" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL DEFAULT 'DEFAULT',
    "edit_window_days" INTEGER NOT NULL DEFAULT 10,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "erp_dpr_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_dpr_settings_key_key" ON "erp_dpr_settings"("key");

INSERT INTO "erp_dpr_settings" ("id", "key", "edit_window_days", "updated_at", "created_at")
VALUES (gen_random_uuid()::text, 'DEFAULT', 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
