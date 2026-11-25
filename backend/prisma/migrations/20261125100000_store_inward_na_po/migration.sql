-- Allow store inward without a PO (NA). PO / PO-line can be linked later.

ALTER TABLE "erp_store_inwards" ALTER COLUMN "purchase_order_id" DROP NOT NULL;
ALTER TABLE "erp_store_inwards" ADD COLUMN IF NOT EXISTS "vendor_name" TEXT;

ALTER TABLE "erp_store_inward_lines" ALTER COLUMN "purchase_order_item_id" DROP NOT NULL;
ALTER TABLE "erp_store_inward_lines" ADD COLUMN IF NOT EXISTS "machine_id" TEXT;

-- Relax FKs: SetNull when PO removed / optional link
ALTER TABLE "erp_store_inwards" DROP CONSTRAINT IF EXISTS "erp_store_inwards_purchase_order_id_fkey";
ALTER TABLE "erp_store_inwards"
  ADD CONSTRAINT "erp_store_inwards_purchase_order_id_fkey"
  FOREIGN KEY ("purchase_order_id") REFERENCES "erp_purchase_orders"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "erp_store_inward_lines" DROP CONSTRAINT IF EXISTS "erp_store_inward_lines_purchase_order_item_id_fkey";
ALTER TABLE "erp_store_inward_lines"
  ADD CONSTRAINT "erp_store_inward_lines_purchase_order_item_id_fkey"
  FOREIGN KEY ("purchase_order_item_id") REFERENCES "erp_purchase_order_items"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

DO $$ BEGIN
  ALTER TABLE "erp_store_inward_lines"
    ADD CONSTRAINT "erp_store_inward_lines_machine_id_fkey"
    FOREIGN KEY ("machine_id") REFERENCES "erp_machines"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS "erp_store_inward_lines_machine_id_idx"
  ON "erp_store_inward_lines"("machine_id");
