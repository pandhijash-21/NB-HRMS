ALTER TABLE "erp_purchase_settings"
  ADD COLUMN IF NOT EXISTS "priority_high_within_days" INTEGER NOT NULL DEFAULT 3;
ALTER TABLE "erp_purchase_settings"
  ADD COLUMN IF NOT EXISTS "priority_med_within_days" INTEGER NOT NULL DEFAULT 7;

-- Agency type lookup: Vendor / Contractor / Other (modifiable via Configurations)
INSERT INTO "system_lookups" ("id", "category", "code", "label", "is_active", "sort_order", "created_at", "updated_at")
VALUES
  (gen_random_uuid()::text, 'CONTRACTOR_TYPE', 'VENDOR', 'Vendor', true, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid()::text, 'CONTRACTOR_TYPE', 'CONTRACTOR', 'Contractor', true, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid()::text, 'CONTRACTOR_TYPE', 'OTHER', 'Other', true, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("category", "code") DO UPDATE SET
  "label" = EXCLUDED."label",
  "is_active" = true,
  "updated_at" = CURRENT_TIMESTAMP;
