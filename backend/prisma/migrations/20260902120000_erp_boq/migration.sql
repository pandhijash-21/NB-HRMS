-- ERP BOQ, materials, machines, labour

CREATE TYPE "ErpBoqRateSource" AS ENUM ('CURRENT_RATE', 'ESTIMATED_RATE');
CREATE TYPE "ErpBoqResourceType" AS ENUM ('MATERIAL', 'MACHINE', 'LABOUR');
CREATE TYPE "ErpStockLogType" AS ENUM ('PURCHASE', 'ADJUSTMENT', 'INITIAL');

ALTER TABLE "erp_activity_subtasks" ADD COLUMN IF NOT EXISTS "description" TEXT;

CREATE TABLE "erp_boqs" (
    "id" TEXT NOT NULL,
    "boq_no" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "rate_source" "ErpBoqRateSource" NOT NULL DEFAULT 'ESTIMATED_RATE',
    "project_id" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" TEXT,
    "updated_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_boqs_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "erp_boqs_boq_no_key" ON "erp_boqs"("boq_no");
CREATE INDEX "erp_boqs_project_id_created_at_idx" ON "erp_boqs"("project_id", "created_at");

CREATE TABLE "erp_boq_tasks" (
    "id" TEXT NOT NULL,
    "boq_id" TEXT NOT NULL,
    "task_id" TEXT NOT NULL,
    "activity_id" TEXT,
    "activity_name" TEXT NOT NULL,
    "subtask_id" TEXT,
    "task_name" TEXT NOT NULL,
    "task_description" TEXT,
    "is_custom_subtask" BOOLEAN NOT NULL DEFAULT false,
    "tower_ids" TEXT,
    "floor_nos" TEXT,
    "unit_ids" TEXT,
    "quantity" DECIMAL(14,4),
    "unit_code" TEXT,
    "rate" DECIMAL(14,2),
    "amount" DECIMAL(14,2),
    "material_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "machine_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "labour_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_boq_tasks_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_boq_tasks_boq_id_sort_order_idx" ON "erp_boq_tasks"("boq_id", "sort_order");

CREATE TABLE "erp_boq_task_resources" (
    "id" TEXT NOT NULL,
    "boq_task_id" TEXT NOT NULL,
    "resource_type" "ErpBoqResourceType" NOT NULL,
    "config_material_id" TEXT,
    "config_machine_id" TEXT,
    "config_labour_id" TEXT,
    "name" TEXT NOT NULL,
    "brand" TEXT,
    "unit_code" TEXT,
    "size" TEXT,
    "quantity" DECIMAL(14,4) NOT NULL,
    "unit_price" DECIMAL(14,2) NOT NULL,
    "total_price" DECIMAL(14,2) NOT NULL,
    "remarks" TEXT,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_boq_task_resources_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_boq_task_resources_boq_task_id_sort_order_idx" ON "erp_boq_task_resources"("boq_task_id", "sort_order");

CREATE TABLE "erp_materials" (
    "id" TEXT NOT NULL,
    "brand" TEXT,
    "name" TEXT NOT NULL,
    "unit_code" TEXT,
    "size" TEXT,
    "activity_id" TEXT,
    "subtask_id" TEXT,
    "qty_on_hand" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_materials_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_materials_is_active_name_idx" ON "erp_materials"("is_active", "name");

CREATE TABLE "erp_material_project_uses" (
    "id" TEXT NOT NULL,
    "material_id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "qty_used" DECIMAL(14,4) NOT NULL DEFAULT 0,
    CONSTRAINT "erp_material_project_uses_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "erp_material_project_uses_material_id_project_id_key" ON "erp_material_project_uses"("material_id", "project_id");

CREATE TABLE "erp_material_stock_logs" (
    "id" TEXT NOT NULL,
    "material_id" TEXT NOT NULL,
    "log_type" "ErpStockLogType" NOT NULL,
    "quantity" DECIMAL(14,4) NOT NULL,
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "erp_material_stock_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_material_stock_logs_material_id_created_at_idx" ON "erp_material_stock_logs"("material_id", "created_at");

CREATE TABLE "erp_machines" (
    "id" TEXT NOT NULL,
    "brand" TEXT,
    "name" TEXT NOT NULL,
    "unit_code" TEXT,
    "size" TEXT,
    "activity_id" TEXT,
    "subtask_id" TEXT,
    "qty_on_hand" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_machines_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_machines_is_active_name_idx" ON "erp_machines"("is_active", "name");

CREATE TABLE "erp_machine_project_uses" (
    "id" TEXT NOT NULL,
    "machine_id" TEXT NOT NULL,
    "project_id" TEXT NOT NULL,
    "qty_used" DECIMAL(14,4) NOT NULL DEFAULT 0,
    CONSTRAINT "erp_machine_project_uses_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "erp_machine_project_uses_machine_id_project_id_key" ON "erp_machine_project_uses"("machine_id", "project_id");

CREATE TABLE "erp_machine_stock_logs" (
    "id" TEXT NOT NULL,
    "machine_id" TEXT NOT NULL,
    "log_type" "ErpStockLogType" NOT NULL,
    "quantity" DECIMAL(14,4) NOT NULL,
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "erp_machine_stock_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_machine_stock_logs_machine_id_created_at_idx" ON "erp_machine_stock_logs"("machine_id", "created_at");

CREATE TABLE "erp_labour" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit_code" TEXT,
    "default_rate" DECIMAL(14,2),
    "activity_id" TEXT,
    "subtask_id" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_labour_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "erp_labour_is_active_name_idx" ON "erp_labour"("is_active", "name");

ALTER TABLE "erp_boqs" ADD CONSTRAINT "erp_boqs_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "erp_boq_tasks" ADD CONSTRAINT "erp_boq_tasks_boq_id_fkey" FOREIGN KEY ("boq_id") REFERENCES "erp_boqs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_boq_task_resources" ADD CONSTRAINT "erp_boq_task_resources_boq_task_id_fkey" FOREIGN KEY ("boq_task_id") REFERENCES "erp_boq_tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_materials" ADD CONSTRAINT "erp_materials_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_materials" ADD CONSTRAINT "erp_materials_subtask_id_fkey" FOREIGN KEY ("subtask_id") REFERENCES "erp_activity_subtasks"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_material_project_uses" ADD CONSTRAINT "erp_material_project_uses_material_id_fkey" FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_material_project_uses" ADD CONSTRAINT "erp_material_project_uses_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_material_stock_logs" ADD CONSTRAINT "erp_material_stock_logs_material_id_fkey" FOREIGN KEY ("material_id") REFERENCES "erp_materials"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machines" ADD CONSTRAINT "erp_machines_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_machines" ADD CONSTRAINT "erp_machines_subtask_id_fkey" FOREIGN KEY ("subtask_id") REFERENCES "erp_activity_subtasks"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_machine_project_uses" ADD CONSTRAINT "erp_machine_project_uses_machine_id_fkey" FOREIGN KEY ("machine_id") REFERENCES "erp_machines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machine_project_uses" ADD CONSTRAINT "erp_machine_project_uses_project_id_fkey" FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machine_stock_logs" ADD CONSTRAINT "erp_machine_stock_logs_machine_id_fkey" FOREIGN KEY ("machine_id") REFERENCES "erp_machines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_labour" ADD CONSTRAINT "erp_labour_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "erp_labour" ADD CONSTRAINT "erp_labour_subtask_id_fkey" FOREIGN KEY ("subtask_id") REFERENCES "erp_activity_subtasks"("id") ON DELETE SET NULL ON UPDATE CASCADE;
