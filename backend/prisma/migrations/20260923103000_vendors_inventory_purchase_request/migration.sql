-- Inventory fields on materials
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "item_code" TEXT;
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "category_code" TEXT;
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "brand_code" TEXT;
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "size_code" TEXT;
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "image_url" TEXT;
ALTER TABLE "erp_materials" ADD COLUMN IF NOT EXISTS "description" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "erp_materials_item_code_key" ON "erp_materials"("item_code");
CREATE INDEX IF NOT EXISTS "erp_materials_category_code_idx" ON "erp_materials"("category_code");

-- Store ↔ Property
ALTER TABLE "erp_store_masters" ADD COLUMN IF NOT EXISTS "property_id" TEXT;
CREATE INDEX IF NOT EXISTS "erp_store_masters_property_id_idx" ON "erp_store_masters"("property_id");
DO $$ BEGIN
  ALTER TABLE "erp_store_masters" ADD CONSTRAINT "erp_store_masters_property_id_fkey"
    FOREIGN KEY ("property_id") REFERENCES "earth_properties"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Purchase request status enum
DO $$ BEGIN
  CREATE TYPE "ErpPurchaseRequestStatus" AS ENUM ('DRAFT', 'PENDING', 'APPROVED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Purchase settings (default approver)
CREATE TABLE IF NOT EXISTS "erp_purchase_settings" (
  "id" TEXT NOT NULL,
  "key" TEXT NOT NULL DEFAULT 'DEFAULT',
  "default_approver_employee_id" INTEGER,
  "updated_at" TIMESTAMP(3) NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "erp_purchase_settings_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_settings_key_key" ON "erp_purchase_settings"("key");
DO $$ BEGIN
  ALTER TABLE "erp_purchase_settings" ADD CONSTRAINT "erp_purchase_settings_default_approver_employee_id_fkey"
    FOREIGN KEY ("default_approver_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Purchase requests
CREATE TABLE IF NOT EXISTS "erp_purchase_requests" (
  "id" TEXT NOT NULL,
  "pr_number" TEXT NOT NULL,
  "pr_date" DATE NOT NULL,
  "pr_type_code" TEXT,
  "project_id" TEXT,
  "activity_id" TEXT,
  "vendor_id" TEXT,
  "requested_by_employee_id" INTEGER,
  "requested_by_user_id" TEXT,
  "required_by_date" DATE,
  "priority_code" TEXT,
  "store_id" TEXT,
  "property_id" TEXT,
  "status" "ErpPurchaseRequestStatus" NOT NULL DEFAULT 'DRAFT',
  "approver_employee_id" INTEGER,
  "approved_at" TIMESTAMP(3),
  "rejection_reason" TEXT,
  "remarks" TEXT,
  "created_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_purchase_requests_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_requests_pr_number_key" ON "erp_purchase_requests"("pr_number");
CREATE INDEX IF NOT EXISTS "erp_purchase_requests_status_pr_date_idx" ON "erp_purchase_requests"("status", "pr_date");
CREATE INDEX IF NOT EXISTS "erp_purchase_requests_approver_employee_id_status_idx" ON "erp_purchase_requests"("approver_employee_id", "status");
CREATE INDEX IF NOT EXISTS "erp_purchase_requests_store_id_idx" ON "erp_purchase_requests"("store_id");
CREATE INDEX IF NOT EXISTS "erp_purchase_requests_vendor_id_idx" ON "erp_purchase_requests"("vendor_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_project_id_fkey"
    FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_activity_id_fkey"
    FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_vendor_id_fkey"
    FOREIGN KEY ("vendor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_store_id_fkey"
    FOREIGN KEY ("store_id") REFERENCES "erp_store_masters"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_requested_by_employee_id_fkey"
    FOREIGN KEY ("requested_by_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_requests" ADD CONSTRAINT "erp_purchase_requests_approver_employee_id_fkey"
    FOREIGN KEY ("approver_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "erp_purchase_request_lines" (
  "id" TEXT NOT NULL,
  "purchase_request_id" TEXT NOT NULL,
  "material_id" TEXT,
  "item_code" TEXT,
  "category_code" TEXT,
  "brand_code" TEXT,
  "brand" TEXT,
  "item_name" TEXT NOT NULL,
  "unit_code" TEXT,
  "size_code" TEXT,
  "size" TEXT,
  "qty" DECIMAL(14,4) NOT NULL,
  "remark" TEXT,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  CONSTRAINT "erp_purchase_request_lines_pkey" PRIMARY KEY ("id")
);
CREATE INDEX IF NOT EXISTS "erp_purchase_request_lines_purchase_request_id_sort_order_idx"
  ON "erp_purchase_request_lines"("purchase_request_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_purchase_request_lines_material_id_idx"
  ON "erp_purchase_request_lines"("material_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_request_lines" ADD CONSTRAINT "erp_purchase_request_lines_purchase_request_id_fkey"
    FOREIGN KEY ("purchase_request_id") REFERENCES "erp_purchase_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_request_lines" ADD CONSTRAINT "erp_purchase_request_lines_material_id_fkey"
    FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
