-- Separate CS approver on purchase settings
ALTER TABLE "erp_purchase_settings" ADD COLUMN IF NOT EXISTS "cs_approver_employee_id" INTEGER;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_settings" ADD CONSTRAINT "erp_purchase_settings_cs_approver_employee_id_fkey"
    FOREIGN KEY ("cs_approver_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Quotation status enum
DO $$ BEGIN
  CREATE TYPE "ErpPurchaseQuotationStatus" AS ENUM ('DRAFT', 'SUBMITTED', 'SELECTED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "erp_purchase_quotations" (
  "id" TEXT NOT NULL,
  "purchase_request_id" TEXT NOT NULL,
  "quotation_no" TEXT NOT NULL,
  "quotation_date" DATE NOT NULL,
  "vendor_id" TEXT,
  "vendor_name" TEXT NOT NULL,
  "address" TEXT,
  "gst_no" TEXT,
  "pan_no" TEXT,
  "status" "ErpPurchaseQuotationStatus" NOT NULL DEFAULT 'DRAFT',
  "total_amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
  "remarks" TEXT,
  "submitted_at" TIMESTAMP(3),
  "selected_at" TIMESTAMP(3),
  "selected_by_employee_id" INTEGER,
  "created_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_purchase_quotations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_quotations_quotation_no_key" ON "erp_purchase_quotations"("quotation_no");
CREATE INDEX IF NOT EXISTS "erp_purchase_quotations_purchase_request_id_status_idx" ON "erp_purchase_quotations"("purchase_request_id", "status");
CREATE INDEX IF NOT EXISTS "erp_purchase_quotations_vendor_id_idx" ON "erp_purchase_quotations"("vendor_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotations" ADD CONSTRAINT "erp_purchase_quotations_purchase_request_id_fkey"
    FOREIGN KEY ("purchase_request_id") REFERENCES "erp_purchase_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotations" ADD CONSTRAINT "erp_purchase_quotations_vendor_id_fkey"
    FOREIGN KEY ("vendor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotations" ADD CONSTRAINT "erp_purchase_quotations_selected_by_employee_id_fkey"
    FOREIGN KEY ("selected_by_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "erp_purchase_quotation_lines" (
  "id" TEXT NOT NULL,
  "quotation_id" TEXT NOT NULL,
  "purchase_request_line_id" TEXT,
  "material_id" TEXT,
  "item_code" TEXT,
  "brand" TEXT,
  "item_name" TEXT NOT NULL,
  "unit_code" TEXT,
  "size" TEXT,
  "qty" DECIMAL(14, 4) NOT NULL,
  "rate" DECIMAL(14, 4) NOT NULL DEFAULT 0,
  "amount" DECIMAL(16, 2) NOT NULL DEFAULT 0,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "erp_purchase_quotation_lines_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_purchase_quotation_lines_quotation_id_sort_order_idx" ON "erp_purchase_quotation_lines"("quotation_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_purchase_quotation_lines_purchase_request_line_id_idx" ON "erp_purchase_quotation_lines"("purchase_request_line_id");
CREATE INDEX IF NOT EXISTS "erp_purchase_quotation_lines_material_id_idx" ON "erp_purchase_quotation_lines"("material_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotation_lines" ADD CONSTRAINT "erp_purchase_quotation_lines_quotation_id_fkey"
    FOREIGN KEY ("quotation_id") REFERENCES "erp_purchase_quotations"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotation_lines" ADD CONSTRAINT "erp_purchase_quotation_lines_purchase_request_line_id_fkey"
    FOREIGN KEY ("purchase_request_line_id") REFERENCES "erp_purchase_request_lines"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_quotation_lines" ADD CONSTRAINT "erp_purchase_quotation_lines_material_id_fkey"
    FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Link final PO back to PR / winning quotation; priced lines
ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "purchase_request_id" TEXT;
ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "quotation_id" TEXT;
ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "total_amount" DECIMAL(16, 2);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_orders_quotation_id_key" ON "erp_purchase_orders"("quotation_id");
CREATE INDEX IF NOT EXISTS "erp_purchase_orders_purchase_request_id_idx" ON "erp_purchase_orders"("purchase_request_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_orders" ADD CONSTRAINT "erp_purchase_orders_purchase_request_id_fkey"
    FOREIGN KEY ("purchase_request_id") REFERENCES "erp_purchase_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_orders" ADD CONSTRAINT "erp_purchase_orders_quotation_id_fkey"
    FOREIGN KEY ("quotation_id") REFERENCES "erp_purchase_quotations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "erp_purchase_order_items" ADD COLUMN IF NOT EXISTS "rate" DECIMAL(14, 4);
ALTER TABLE "erp_purchase_order_items" ADD COLUMN IF NOT EXISTS "amount" DECIMAL(16, 2);
