-- Expand ERP contractors with locations, contacts, documents

ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "mobile_no" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "alternate_mobile_no" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "tds_code" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "bank_name" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "branch_name" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "ifsc_code" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "account_no" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "payment_terms" TEXT;
ALTER TABLE "erp_contractors" ADD COLUMN IF NOT EXISTS "contractor_type_code" TEXT;

-- Backfill mobile from legacy phone
UPDATE "erp_contractors" SET "mobile_no" = "phone" WHERE "mobile_no" IS NULL AND "phone" IS NOT NULL;

CREATE TABLE IF NOT EXISTS "erp_contractor_locations" (
    "id" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "location_name" TEXT,
    "address_type_code" TEXT,
    "country_code" TEXT,
    "state_code" TEXT,
    "city_code" TEXT,
    "address1" TEXT,
    "address2" TEXT,
    "post_code" TEXT,
    "pan_no" TEXT,
    "gst_no" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_contractor_locations_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_contractor_locations_contractor_id_sort_order_idx" ON "erp_contractor_locations"("contractor_id", "sort_order");

CREATE TABLE IF NOT EXISTS "erp_contractor_contacts" (
    "id" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT,
    "country_code" TEXT,
    "mobile_no" TEXT,
    "alt_country_code" TEXT,
    "alternate_mobile_no" TEXT,
    "designation" TEXT,
    "location_name" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_contractor_contacts_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_contractor_contacts_contractor_id_sort_order_idx" ON "erp_contractor_contacts"("contractor_id", "sort_order");

CREATE TABLE IF NOT EXISTS "erp_contractor_documents" (
    "id" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "type_code" TEXT,
    "name" TEXT,
    "remarks" TEXT,
    "file_url" TEXT,
    "file_name" TEXT,
    "mime_type" TEXT,
    "file_size" INTEGER,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_contractor_documents_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_contractor_documents_contractor_id_sort_order_idx" ON "erp_contractor_documents"("contractor_id", "sort_order");

DO $$ BEGIN
  ALTER TABLE "erp_contractor_locations" ADD CONSTRAINT "erp_contractor_locations_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_contractor_contacts" ADD CONSTRAINT "erp_contractor_contacts_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_contractor_documents" ADD CONSTRAINT "erp_contractor_documents_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
