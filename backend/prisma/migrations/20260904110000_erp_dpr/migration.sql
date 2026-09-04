-- CreateEnum
DO $$ BEGIN
  ALTER TYPE "ErpStockLogType" ADD VALUE IF NOT EXISTS 'CONSUMPTION';
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- CreateTable
CREATE TABLE IF NOT EXISTS "erp_dprs" (
    "id" TEXT NOT NULL,
    "dpr_no" TEXT NOT NULL,
    "report_date" DATE NOT NULL,
    "project_id" TEXT NOT NULL,
    "created_by_name" TEXT,
    "remarks" TEXT,
    "created_by" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_dprs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_dpr_lines" (
    "id" TEXT NOT NULL,
    "dpr_id" TEXT NOT NULL,
    "contractor_id" TEXT,
    "contractor_name" TEXT,
    "activity_id" TEXT,
    "activity_name" TEXT,
    "subtask_id" TEXT,
    "task_name" TEXT,
    "tower_id" TEXT,
    "tower_name" TEXT,
    "floor_no" INTEGER,
    "unit_id" TEXT,
    "unit_label" TEXT,
    "unit_code" TEXT,
    "consumed_qty" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "grade_code" TEXT,
    "remarks" TEXT,
    "status_code" TEXT,
    "completion_pct" DECIMAL(5,2),
    "actual_start_date" DATE,
    "actual_end_date" DATE,
    "material_rate_text" TEXT,
    "labour_rate_text" TEXT,
    "machine_rate_text" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_dpr_lines_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_dpr_material_lines" (
    "id" TEXT NOT NULL,
    "dpr_line_id" TEXT NOT NULL,
    "material_id" TEXT,
    "item_code" TEXT,
    "category" TEXT,
    "item_name" TEXT NOT NULL,
    "brand" TEXT,
    "unit_code" TEXT,
    "size" TEXT,
    "consumed_qty" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "remarks" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "erp_dpr_material_lines_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_dpr_labour_lines" (
    "id" TEXT NOT NULL,
    "dpr_line_id" TEXT NOT NULL,
    "labour_id" TEXT,
    "name" TEXT NOT NULL,
    "unit_code" TEXT,
    "consumed_qty" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "remarks" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "erp_dpr_labour_lines_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_dpr_machine_lines" (
    "id" TEXT NOT NULL,
    "dpr_line_id" TEXT NOT NULL,
    "machine_id" TEXT,
    "item_name" TEXT NOT NULL,
    "brand" TEXT,
    "unit_code" TEXT,
    "size" TEXT,
    "consumed_qty" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "remarks" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "erp_dpr_machine_lines_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_dprs_dpr_no_key" ON "erp_dprs"("dpr_no");
CREATE INDEX IF NOT EXISTS "erp_dprs_project_id_report_date_idx" ON "erp_dprs"("project_id", "report_date");
CREATE INDEX IF NOT EXISTS "erp_dprs_created_at_idx" ON "erp_dprs"("created_at");
CREATE INDEX IF NOT EXISTS "erp_dpr_lines_dpr_id_sort_order_idx" ON "erp_dpr_lines"("dpr_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_dpr_lines_contractor_id_idx" ON "erp_dpr_lines"("contractor_id");
CREATE INDEX IF NOT EXISTS "erp_dpr_material_lines_dpr_line_id_sort_order_idx" ON "erp_dpr_material_lines"("dpr_line_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_dpr_labour_lines_dpr_line_id_sort_order_idx" ON "erp_dpr_labour_lines"("dpr_line_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_dpr_machine_lines_dpr_line_id_sort_order_idx" ON "erp_dpr_machine_lines"("dpr_line_id", "sort_order");

DO $$ BEGIN
  ALTER TABLE "erp_dprs" ADD CONSTRAINT "erp_dprs_project_id_fkey"
    FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_dpr_lines" ADD CONSTRAINT "erp_dpr_lines_dpr_id_fkey"
    FOREIGN KEY ("dpr_id") REFERENCES "erp_dprs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_dpr_lines" ADD CONSTRAINT "erp_dpr_lines_contractor_id_fkey"
    FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_dpr_material_lines" ADD CONSTRAINT "erp_dpr_material_lines_dpr_line_id_fkey"
    FOREIGN KEY ("dpr_line_id") REFERENCES "erp_dpr_lines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_dpr_labour_lines" ADD CONSTRAINT "erp_dpr_labour_lines_dpr_line_id_fkey"
    FOREIGN KEY ("dpr_line_id") REFERENCES "erp_dpr_lines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_dpr_machine_lines" ADD CONSTRAINT "erp_dpr_machine_lines_dpr_line_id_fkey"
    FOREIGN KEY ("dpr_line_id") REFERENCES "erp_dpr_lines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
