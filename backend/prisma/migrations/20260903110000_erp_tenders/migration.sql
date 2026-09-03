-- ERP Tenders + Tender Applications

CREATE TYPE "ErpTenderStatus" AS ENUM ('DRAFT', 'OPEN', 'CLOSED', 'CANCELLED');
CREATE TYPE "ErpTenderApplicationStatus" AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'ACCEPTED', 'REJECTED');

CREATE TABLE "erp_tenders" (
    "id" TEXT NOT NULL,
    "tender_no" TEXT NOT NULL,
    "tender_date" DATE NOT NULL,
    "created_by_name" TEXT,
    "project_id" TEXT NOT NULL,
    "boq_id" TEXT,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "status" "ErpTenderStatus" NOT NULL DEFAULT 'OPEN',
    "remarks" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_tenders_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "erp_tenders_tender_no_key" ON "erp_tenders"("tender_no");
CREATE INDEX "erp_tenders_project_id_created_at_idx" ON "erp_tenders"("project_id", "created_at");
CREATE INDEX "erp_tenders_boq_id_idx" ON "erp_tenders"("boq_id");
CREATE INDEX "erp_tenders_status_is_active_idx" ON "erp_tenders"("status", "is_active");

CREATE TABLE "erp_tender_lines" (
    "id" TEXT NOT NULL,
    "tender_id" TEXT NOT NULL,
    "activity_id" TEXT,
    "activity_name" TEXT NOT NULL,
    "boq_task_id" TEXT,
    "task_id" TEXT,
    "task_name" TEXT NOT NULL,
    "task_description" TEXT,
    "tower_ids" TEXT,
    "floor_nos" TEXT,
    "unit_ids" TEXT,
    "quantity" DECIMAL(14,4),
    "unit_code" TEXT,
    "rate" DECIMAL(14,2),
    "amount" DECIMAL(14,2),
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_tender_lines_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_tender_lines_tender_id_sort_order_idx" ON "erp_tender_lines"("tender_id", "sort_order");

CREATE TABLE "erp_tender_applications" (
    "id" TEXT NOT NULL,
    "tender_id" TEXT NOT NULL,
    "vendor_name" TEXT NOT NULL,
    "vendor_contact" TEXT,
    "application_date" DATE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "quoted_amount" DECIMAL(14,2),
    "status" "ErpTenderApplicationStatus" NOT NULL DEFAULT 'SUBMITTED',
    "remarks" TEXT,
    "created_by" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_tender_applications_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_tender_applications_tender_id_created_at_idx" ON "erp_tender_applications"("tender_id", "created_at");
CREATE INDEX "erp_tender_applications_status_idx" ON "erp_tender_applications"("status");

ALTER TABLE "erp_tenders" ADD CONSTRAINT "erp_tenders_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "erp_tenders" ADD CONSTRAINT "erp_tenders_boq_id_fkey" FOREIGN KEY ("boq_id") REFERENCES "erp_boqs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_tender_lines" ADD CONSTRAINT "erp_tender_lines_tender_id_fkey" FOREIGN KEY ("tender_id") REFERENCES "erp_tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_tender_applications" ADD CONSTRAINT "erp_tender_applications_tender_id_fkey" FOREIGN KEY ("tender_id") REFERENCES "erp_tenders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
