ALTER TABLE "erp_purchase_settings" ADD COLUMN IF NOT EXISTS "default_po_terms" JSONB;

ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "terms_and_conditions" JSONB;
ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "cgst_rate" DECIMAL(6, 2) DEFAULT 9;
ALTER TABLE "erp_purchase_orders" ADD COLUMN IF NOT EXISTS "sgst_rate" DECIMAL(6, 2) DEFAULT 9;

ALTER TABLE "erp_purchase_order_items" ADD COLUMN IF NOT EXISTS "hsn_code" TEXT;
