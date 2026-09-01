-- ERP Work Orders, Activities, Contractors
-- Idempotent: safe to re-run after a failed/partial apply (deploy health timeout).

DO $$ BEGIN
  CREATE TYPE "ErpWorkOrderStatus" AS ENUM (
    'ISSUED',
    'IN_PROGRESS',
    'COMPLETED',
    'COMPLETED_DELAYED',
    'CANCELLED'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ErpWorkOrderApprovalStatus" AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED',
    'NOT_APPLICABLE'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "erp_contractors" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "contact_person" TEXT,
  "phone" TEXT,
  "email" TEXT,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_contractors_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_activities" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_activities_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_activity_subtasks" (
  "id" TEXT NOT NULL,
  "activity_id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_activity_subtasks_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_work_orders" (
  "id" TEXT NOT NULL,
  "work_order_id" TEXT NOT NULL,
  "order_date" DATE NOT NULL,
  "due_date" DATE,
  "project_id" TEXT NOT NULL,
  "tender_ref" TEXT,
  "contractor_id" TEXT,
  "category_code" TEXT,
  "status" "ErpWorkOrderStatus" NOT NULL DEFAULT 'ISSUED',
  "approval_status" "ErpWorkOrderApprovalStatus" NOT NULL DEFAULT 'PENDING',
  "approver_employee_id" INTEGER,
  "owner_employee_id" INTEGER,
  "total_amount" DECIMAL(14,2) NOT NULL DEFAULT 0,
  "created_by" TEXT,
  "updated_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_work_orders_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_work_order_activity_groups" (
  "id" TEXT NOT NULL,
  "work_order_id" TEXT NOT NULL,
  "activity_id" TEXT,
  "activity_name" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_work_order_activity_groups_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "erp_work_order_lines" (
  "id" TEXT NOT NULL,
  "group_id" TEXT NOT NULL,
  "work_detail" TEXT NOT NULL,
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
  CONSTRAINT "erp_work_order_lines_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_work_orders_work_order_id_key" ON "erp_work_orders"("work_order_id");
CREATE INDEX IF NOT EXISTS "erp_contractors_is_active_name_idx" ON "erp_contractors"("is_active", "name");
CREATE INDEX IF NOT EXISTS "erp_activities_is_active_sort_order_idx" ON "erp_activities"("is_active", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_activity_subtasks_activity_id_sort_order_idx" ON "erp_activity_subtasks"("activity_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_work_orders_project_id_order_date_idx" ON "erp_work_orders"("project_id", "order_date");
CREATE INDEX IF NOT EXISTS "erp_work_orders_status_idx" ON "erp_work_orders"("status");
CREATE INDEX IF NOT EXISTS "erp_work_orders_approval_status_idx" ON "erp_work_orders"("approval_status");
CREATE INDEX IF NOT EXISTS "erp_work_order_activity_groups_work_order_id_sort_order_idx" ON "erp_work_order_activity_groups"("work_order_id", "sort_order");
CREATE INDEX IF NOT EXISTS "erp_work_order_lines_group_id_sort_order_idx" ON "erp_work_order_lines"("group_id", "sort_order");

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_activity_subtasks_activity_id_fkey') THEN
    ALTER TABLE "erp_activity_subtasks"
      ADD CONSTRAINT "erp_activity_subtasks_activity_id_fkey"
      FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF to_regclass('public.erp_projects') IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_orders_project_id_fkey') THEN
    ALTER TABLE "erp_work_orders"
      ADD CONSTRAINT "erp_work_orders_project_id_fkey"
      FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_orders_contractor_id_fkey') THEN
    ALTER TABLE "erp_work_orders"
      ADD CONSTRAINT "erp_work_orders_contractor_id_fkey"
      FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_orders_owner_employee_id_fkey') THEN
    ALTER TABLE "erp_work_orders"
      ADD CONSTRAINT "erp_work_orders_owner_employee_id_fkey"
      FOREIGN KEY ("owner_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_orders_approver_employee_id_fkey') THEN
    ALTER TABLE "erp_work_orders"
      ADD CONSTRAINT "erp_work_orders_approver_employee_id_fkey"
      FOREIGN KEY ("approver_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_order_activity_groups_work_order_id_fkey') THEN
    ALTER TABLE "erp_work_order_activity_groups"
      ADD CONSTRAINT "erp_work_order_activity_groups_work_order_id_fkey"
      FOREIGN KEY ("work_order_id") REFERENCES "erp_work_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_order_activity_groups_activity_id_fkey') THEN
    ALTER TABLE "erp_work_order_activity_groups"
      ADD CONSTRAINT "erp_work_order_activity_groups_activity_id_fkey"
      FOREIGN KEY ("activity_id") REFERENCES "erp_activities"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_work_order_lines_group_id_fkey') THEN
    ALTER TABLE "erp_work_order_lines"
      ADD CONSTRAINT "erp_work_order_lines_group_id_fkey"
      FOREIGN KEY ("group_id") REFERENCES "erp_work_order_activity_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
