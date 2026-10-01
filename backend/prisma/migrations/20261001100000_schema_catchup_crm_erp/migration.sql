-- Catch-up for schema fields added after prod switched from db push to migrate deploy.
-- Idempotent: safe on DBs that already have some of these (e.g. dev DBs synced via db push).

-- AlterEnum
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'CNR';
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'SCHEDULED_VISIT';
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'SITE_VISIT_DONE';
ALTER TYPE "ErpTenderApplicationStatus" ADD VALUE IF NOT EXISTS 'APPROVED';

-- AlterTable
ALTER TABLE "crm_leads"
ADD COLUMN IF NOT EXISTS "not_interested_reason" TEXT,
ADD COLUMN IF NOT EXISTS "not_interested_remark" TEXT,
ADD COLUMN IF NOT EXISTS "scheduled_visit_at" TIMESTAMP(3),
ADD COLUMN IF NOT EXISTS "visited_at" TIMESTAMP(3),
ADD COLUMN IF NOT EXISTS "lead_source" TEXT,
ADD COLUMN IF NOT EXISTS "channel_partner_name" TEXT,
ADD COLUMN IF NOT EXISTS "reference_type" TEXT,
ADD COLUMN IF NOT EXISTS "reference_name" TEXT;

-- Dev DBs created via db push have "itemName"; migrated DBs have "item_name".
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'erp_dpr_material_lines' AND column_name = 'itemName')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'erp_dpr_material_lines' AND column_name = 'item_name') THEN
    ALTER TABLE "erp_dpr_material_lines" RENAME COLUMN "itemName" TO "item_name";
  END IF;
END $$;

-- CreateTable
CREATE TABLE IF NOT EXISTS "erp_payment_plans" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "description" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sequence" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_payment_plans_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_payment_plans_code_key" ON "erp_payment_plans"("code");

-- AlterTable
ALTER TABLE "erp_payment_terms" ADD COLUMN IF NOT EXISTS "plan_id" TEXT;

CREATE INDEX IF NOT EXISTS "erp_payment_terms_plan_id_sequence_idx" ON "erp_payment_terms"("plan_id", "sequence");

DO $$ BEGIN
  ALTER TABLE "erp_payment_terms" ADD CONSTRAINT "erp_payment_terms_plan_id_fkey"
    FOREIGN KEY ("plan_id") REFERENCES "erp_payment_plans"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- CreateTable
CREATE TABLE IF NOT EXISTS "erp_pricing_components" (
    "id" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "formula_type" TEXT NOT NULL DEFAULT 'AREA_RATE',
    "formula_preview" TEXT NOT NULL DEFAULT '',
    "reference_base" TEXT,
    "default_rate" DECIMAL(14, 2),
    "rate_unit" TEXT DEFAULT '₹/sq.ft',
    "is_required" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sequence" INTEGER NOT NULL DEFAULT 0,
    "description" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_pricing_components_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_pricing_components_code_key" ON "erp_pricing_components"("code");
CREATE INDEX IF NOT EXISTS "erp_pricing_components_category_is_active_sequence_idx" ON "erp_pricing_components"("category", "is_active", "sequence");
