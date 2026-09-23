-- Store masters, purchase order stub, PO-based goods inward
-- Idempotent: enums/tables may already exist from prior partial applies.

DO $$ BEGIN
  CREATE TYPE "ErpPurchaseOrderStatus" AS ENUM ('DRAFT', 'OPEN', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ErpStoreInwardQcStatus" AS ENUM ('PASSED', 'PARTIAL_PASS', 'FAIL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "erp_store_masters" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_store_masters_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_purchase_orders" (
    "id" TEXT NOT NULL,
    "po_number" TEXT NOT NULL,
    "vendor_name" TEXT NOT NULL,
    "vendor_id" TEXT,
    "project_id" TEXT,
    "order_date" DATE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" "ErpPurchaseOrderStatus" NOT NULL DEFAULT 'OPEN',
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_purchase_orders_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_purchase_order_items" (
    "id" TEXT NOT NULL,
    "purchase_order_id" TEXT NOT NULL,
    "material_id" TEXT,
    "item_name" TEXT NOT NULL,
    "brand" TEXT,
    "unit_code" TEXT,
    "size" TEXT,
    "ordered_qty" DECIMAL(14,4) NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "erp_purchase_order_items_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_store_inwards" (
    "id" TEXT NOT NULL,
    "purchase_order_id" TEXT NOT NULL,
    "store_id" TEXT NOT NULL,
    "inward_date" DATE NOT NULL,
    "truck_number" TEXT,
    "challan_number" TEXT,
    "challan_image_url" TEXT,
    "qc_status" "ErpStoreInwardQcStatus" NOT NULL,
    "quantity_rejected" DECIMAL(14,4),
    "return_date" DATE,
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_store_inwards_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_store_inward_lines" (
    "id" TEXT NOT NULL,
    "inward_id" TEXT NOT NULL,
    "purchase_order_item_id" TEXT NOT NULL,
    "material_id" TEXT,
    "item_name" TEXT NOT NULL,
    "brand" TEXT,
    "unit_code" TEXT,
    "size" TEXT,
    "quantity_received" DECIMAL(14,4) NOT NULL,
    "quantity_accepted" DECIMAL(14,4) NOT NULL,
    "quantity_rejected" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT "erp_store_inward_lines_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_orders_po_number_key" ON "erp_purchase_orders"("po_number");
CREATE INDEX IF NOT EXISTS "erp_store_masters_is_active_name_idx" ON "erp_store_masters"("is_active", "name");
CREATE INDEX IF NOT EXISTS "erp_purchase_orders_status_order_date_idx" ON "erp_purchase_orders"("status", "order_date");
CREATE INDEX IF NOT EXISTS "erp_purchase_orders_vendor_id_idx" ON "erp_purchase_orders"("vendor_id");
CREATE INDEX IF NOT EXISTS "erp_purchase_order_items_purchase_order_id_sort_order_idx" ON "erp_purchase_order_items"("purchase_order_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_purchase_order_items_material_id_idx" ON "erp_purchase_order_items"("material_id");
CREATE INDEX IF NOT EXISTS "erp_store_inwards_purchase_order_id_inward_date_idx" ON "erp_store_inwards"("purchase_order_id", "inward_date");
CREATE INDEX IF NOT EXISTS "erp_store_inwards_store_id_inward_date_idx" ON "erp_store_inwards"("store_id", "inward_date");
CREATE INDEX IF NOT EXISTS "erp_store_inward_lines_inward_id_sort_order_idx" ON "erp_store_inward_lines"("inward_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_store_inward_lines_purchase_order_item_id_idx" ON "erp_store_inward_lines"("purchase_order_item_id");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_orders" ADD CONSTRAINT "erp_purchase_orders_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_order_items" ADD CONSTRAINT "erp_purchase_order_items_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "erp_purchase_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_purchase_order_items" ADD CONSTRAINT "erp_purchase_order_items_material_id_fkey" FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_store_inwards" ADD CONSTRAINT "erp_store_inwards_purchase_order_id_fkey" FOREIGN KEY ("purchase_order_id") REFERENCES "erp_purchase_orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_store_inwards" ADD CONSTRAINT "erp_store_inwards_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "erp_store_masters"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_store_inward_lines" ADD CONSTRAINT "erp_store_inward_lines_inward_id_fkey" FOREIGN KEY ("inward_id") REFERENCES "erp_store_inwards"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_store_inward_lines" ADD CONSTRAINT "erp_store_inward_lines_purchase_order_item_id_fkey" FOREIGN KEY ("purchase_order_item_id") REFERENCES "erp_purchase_order_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
  ALTER TABLE "erp_store_inward_lines" ADD CONSTRAINT "erp_store_inward_lines_material_id_fkey" FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
