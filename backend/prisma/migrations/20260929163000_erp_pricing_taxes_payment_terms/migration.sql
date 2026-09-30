-- AlterTable
ALTER TABLE "erp_project_units"
ADD COLUMN IF NOT EXISTS "total_unit_value" DECIMAL(14, 2),
ADD COLUMN IF NOT EXISTS "taxes" JSONB,
ADD COLUMN IF NOT EXISTS "maintenance" JSONB,
ADD COLUMN IF NOT EXISTS "other_charges" JSONB,
ADD COLUMN IF NOT EXISTS "payment_terms" JSONB,
ADD COLUMN IF NOT EXISTS "grand_total" DECIMAL(14, 2);

-- CreateTable
CREATE TABLE IF NOT EXISTS "erp_payment_terms" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "percent_payment" DECIMAL(6, 2) NOT NULL,
    "last_day_months" DECIMAL(6, 2) NOT NULL,
    "sequence" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_payment_terms_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "erp_payment_terms_is_active_sequence_idx" ON "erp_payment_terms"("is_active", "sequence");
