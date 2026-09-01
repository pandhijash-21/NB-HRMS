-- ERP Projects (sites, towers, units) — required before work orders FK.
-- Idempotent for prod recovery after partial/failed deploys.

CREATE TABLE IF NOT EXISTS "erp_projects" (
  "id" TEXT NOT NULL,
  "project_no" SERIAL NOT NULL,
  "name" TEXT NOT NULL,
  "organization_id" TEXT,
  "institute_id" TEXT,
  "category_code" TEXT,
  "sub_category_code" TEXT,
  "structure_code" TEXT,
  "segment_code" TEXT,
  "rera_no" TEXT,
  "expected_completion_date" DATE,
  "notes" TEXT,
  "status_code" TEXT NOT NULL DEFAULT 'ACTIVE',
  "owner_employee_id" INTEGER,
  "total_project_area" DECIMAL(14,2),
  "area_unit_code" TEXT,
  "estimated_cost" DECIMAL(14,2),
  "image_url" TEXT,
  "address" TEXT,
  "landmark" TEXT,
  "country_code" TEXT,
  "state_code" TEXT,
  "city_code" TEXT,
  "area_code" TEXT,
  "pincode" TEXT,
  "total_plot_area" DECIMAL(14,2),
  "amenities_code" TEXT,
  "livability_code" TEXT,
  "bank_tie_up_code" TEXT,
  "development_authority_code" TEXT,
  "electricity_provider_code" TEXT,
  "spec_notes" TEXT,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_by" TEXT,
  "updated_by" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_projects_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_projects_project_no_key" ON "erp_projects"("project_no");
CREATE INDEX IF NOT EXISTS "erp_projects_is_active_created_at_idx" ON "erp_projects"("is_active", "created_at");
CREATE INDEX IF NOT EXISTS "erp_projects_organization_id_idx" ON "erp_projects"("organization_id");
CREATE INDEX IF NOT EXISTS "erp_projects_institute_id_idx" ON "erp_projects"("institute_id");
CREATE INDEX IF NOT EXISTS "erp_projects_status_code_idx" ON "erp_projects"("status_code");

CREATE TABLE IF NOT EXISTS "erp_project_documents" (
  "id" TEXT NOT NULL,
  "project_id" TEXT NOT NULL,
  "type_code" TEXT,
  "name" TEXT NOT NULL,
  "remarks" TEXT,
  "file_url" TEXT NOT NULL,
  "file_name" TEXT,
  "mime_type" TEXT,
  "file_size" INTEGER,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_project_documents_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_project_documents_project_id_idx" ON "erp_project_documents"("project_id");

CREATE TABLE IF NOT EXISTS "erp_project_towers" (
  "id" TEXT NOT NULL,
  "project_id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "phase" TEXT,
  "basement_count" INTEGER NOT NULL DEFAULT 0,
  "floor_count" INTEGER NOT NULL,
  "flats_per_floor" INTEGER NOT NULL,
  "has_ground" BOOLEAN NOT NULL DEFAULT false,
  "sequence" INTEGER NOT NULL DEFAULT 0,
  "status_code" TEXT NOT NULL DEFAULT 'ACTIVE',
  "remarks" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_project_towers_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "erp_project_towers_project_id_sequence_idx" ON "erp_project_towers"("project_id", "sequence");

CREATE TABLE IF NOT EXISTS "erp_project_units" (
  "id" TEXT NOT NULL,
  "tower_id" TEXT NOT NULL,
  "unit_no" TEXT NOT NULL,
  "unit_type_code" TEXT,
  "floor_no" INTEGER NOT NULL,
  "super_built_up" DECIMAL(14,2),
  "carpet_area" DECIMAL(14,2),
  "area_unit_code" TEXT,
  "status_code" TEXT NOT NULL DEFAULT 'AVAILABLE',
  "facing_code" TEXT,
  "category_code" TEXT,
  "built_up_area" DECIMAL(14,2),
  "balcony_area" DECIMAL(14,2),
  "terrace_area" DECIMAL(14,2),
  "plot_area" DECIMAL(14,2),
  "parking_allocation" TEXT,
  "plc" DECIMAL(14,2),
  "base_rate" DECIMAL(14,2),
  "total_value" DECIMAL(14,2),
  "remarks" TEXT,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "erp_project_units_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_project_units_tower_id_unit_no_key" ON "erp_project_units"("tower_id", "unit_no");
CREATE INDEX IF NOT EXISTS "erp_project_units_tower_id_floor_no_idx" ON "erp_project_units"("tower_id", "floor_no");

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_projects_organization_id_fkey') THEN
    ALTER TABLE "erp_projects"
      ADD CONSTRAINT "erp_projects_organization_id_fkey"
      FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_projects_institute_id_fkey') THEN
    ALTER TABLE "erp_projects"
      ADD CONSTRAINT "erp_projects_institute_id_fkey"
      FOREIGN KEY ("institute_id") REFERENCES "institutes"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_projects_owner_employee_id_fkey') THEN
    ALTER TABLE "erp_projects"
      ADD CONSTRAINT "erp_projects_owner_employee_id_fkey"
      FOREIGN KEY ("owner_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_project_documents_project_id_fkey') THEN
    ALTER TABLE "erp_project_documents"
      ADD CONSTRAINT "erp_project_documents_project_id_fkey"
      FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_project_towers_project_id_fkey') THEN
    ALTER TABLE "erp_project_towers"
      ADD CONSTRAINT "erp_project_towers_project_id_fkey"
      FOREIGN KEY ("project_id") REFERENCES "erp_projects"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'erp_project_units_tower_id_fkey') THEN
    ALTER TABLE "erp_project_units"
      ADD CONSTRAINT "erp_project_units_tower_id_fkey"
      FOREIGN KEY ("tower_id") REFERENCES "erp_project_towers"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
