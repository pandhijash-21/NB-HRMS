-- Quotation commercial terms: GST mode, freight, payment, delivery, rating
ALTER TABLE "erp_purchase_quotations"
ADD COLUMN IF NOT EXISTS "gst_mode" TEXT NOT NULL DEFAULT 'INCLUSIVE',
ADD COLUMN IF NOT EXISTS "gst_tax_type" TEXT,
ADD COLUMN IF NOT EXISTS "vendor_state_code" TEXT,
ADD COLUMN IF NOT EXISTS "cgst_rate" DECIMAL(6, 2),
ADD COLUMN IF NOT EXISTS "sgst_rate" DECIMAL(6, 2),
ADD COLUMN IF NOT EXISTS "igst_rate" DECIMAL(6, 2),
ADD COLUMN IF NOT EXISTS "cgst_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS "sgst_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS "igst_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS "freight_mode" TEXT NOT NULL DEFAULT 'INCLUSIVE',
ADD COLUMN IF NOT EXISTS "freight_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS "payment_terms" TEXT,
ADD COLUMN IF NOT EXISTS "delivery_days" INTEGER,
ADD COLUMN IF NOT EXISTS "rating" DECIMAL(3, 1),
ADD COLUMN IF NOT EXISTS "final_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0;

UPDATE "erp_purchase_quotations" q
SET "final_amount" = COALESCE(q."total_amount", 0)
WHERE q."final_amount" = 0 AND COALESCE(q."total_amount", 0) <> 0;
