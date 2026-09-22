-- Reimbursement km photos + attendance half-day windows
ALTER TABLE "reimbursement_claims"
  ADD COLUMN IF NOT EXISTS "opening_km_photo_url" TEXT,
  ADD COLUMN IF NOT EXISTS "closing_km_photo_url" TEXT;

ALTER TABLE "attendance_policy"
  ADD COLUMN IF NOT EXISTS "half_day_windows" JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Ensure every pay commission has a mandatory Reimbursement earning column
INSERT INTO "salary_column_definitions" (
  "id",
  "pay_commission_id",
  "column_identifier",
  "display_name",
  "category",
  "evaluation_order",
  "is_rule_configurable",
  "cut_on_leave",
  "cut_on_absent"
)
SELECT
  gen_random_uuid()::text,
  pc.id,
  'reimbursement',
  'Reimbursement',
  'EARNING',
  105,
  true,
  false,
  false
FROM "pay_commissions" pc
WHERE NOT EXISTS (
  SELECT 1
  FROM "salary_column_definitions" d
  WHERE d.pay_commission_id = pc.id
    AND d.column_identifier = 'reimbursement'
    AND d.category = 'EARNING'
);
