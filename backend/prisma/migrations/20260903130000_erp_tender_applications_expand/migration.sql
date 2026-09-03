-- Expand tender applications for contractor-based form

ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "application_no" TEXT;
ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "project_id" TEXT;
ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "activity_id" TEXT;
ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "activity_name" TEXT;
ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "contractor_id" TEXT;
ALTER TABLE "erp_tender_applications" ADD COLUMN IF NOT EXISTS "created_by_name" TEXT;

-- Backfill application numbers for any existing rows
WITH numbered AS (
  SELECT id, 'APN' || LPAD(ROW_NUMBER() OVER (ORDER BY created_at)::text, 5, '0') AS app_no
  FROM "erp_tender_applications"
  WHERE "application_no" IS NULL
)
UPDATE "erp_tender_applications" t
SET "application_no" = n.app_no
FROM numbered n
WHERE t.id = n.id;

UPDATE "erp_tender_applications"
SET "application_no" = 'APN' || SUBSTRING(REPLACE(id::text, '-', ''), 1, 8)
WHERE "application_no" IS NULL;

ALTER TABLE "erp_tender_applications" ALTER COLUMN "application_no" SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS "erp_tender_applications_application_no_key" ON "erp_tender_applications"("application_no");
CREATE INDEX IF NOT EXISTS "erp_tender_applications_project_id_idx" ON "erp_tender_applications"("project_id");
CREATE INDEX IF NOT EXISTS "erp_tender_applications_contractor_id_idx" ON "erp_tender_applications"("contractor_id");

DO $$ BEGIN
  ALTER TABLE "erp_tender_applications" ADD CONSTRAINT "erp_tender_applications_contractor_id_fkey"
    FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
