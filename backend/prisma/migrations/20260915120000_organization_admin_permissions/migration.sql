-- CreateTable
CREATE TABLE IF NOT EXISTS "organization_admin_permissions" (
    "id" TEXT NOT NULL,
    "organization_id" TEXT NOT NULL,
    "module_key" TEXT NOT NULL,
    "can_read" BOOLEAN NOT NULL DEFAULT false,
    "can_write" BOOLEAN NOT NULL DEFAULT false,
    "can_approve" BOOLEAN NOT NULL DEFAULT false,
    "can_delete" BOOLEAN NOT NULL DEFAULT false,
    "can_export" BOOLEAN NOT NULL DEFAULT false,
    "employee_view_scope" "EmployeeViewScope" NOT NULL DEFAULT 'NONE',
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "organization_admin_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "organization_admin_permissions_organization_id_idx" ON "organization_admin_permissions"("organization_id");

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "organization_admin_permissions_organization_id_module_key_key" ON "organization_admin_permissions"("organization_id", "module_key");

-- AddForeignKey
DO $$ BEGIN
  ALTER TABLE "organization_admin_permissions"
    ADD CONSTRAINT "organization_admin_permissions_organization_id_fkey"
    FOREIGN KEY ("organization_id") REFERENCES "organizations"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE "organization_admin_permissions"
    ADD CONSTRAINT "organization_admin_permissions_module_key_fkey"
    FOREIGN KEY ("module_key") REFERENCES "system_modules"("key")
    ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Backfill: grant full access within each org's licensed suites + COLLABORATION
INSERT INTO "organization_admin_permissions" (
  "id", "organization_id", "module_key",
  "can_read", "can_write", "can_approve", "can_delete", "can_export",
  "employee_view_scope", "updated_at"
)
SELECT
  gen_random_uuid()::text,
  o.id,
  m.key,
  true, true, true, true, true,
  CASE WHEN m.key = 'PERSONAL_INFO' THEN 'UNIVERSITY'::"EmployeeViewScope" ELSE 'NONE'::"EmployeeViewScope" END,
  NOW()
FROM "organizations" o
CROSS JOIN "system_modules" m
WHERE o.deleted_at IS NULL
  AND m.is_active = true
  AND (
    UPPER(COALESCE(m.category, 'HRMS')) = 'COLLABORATION'
    OR UPPER(COALESCE(m.category, 'HRMS')) = ANY (
      CASE
        WHEN o.tag_line IS NULL OR o.tag_line = '' THEN ARRAY['HRMS','CRM','ERP']
        WHEN o.tag_line LIKE '[%' THEN (
          SELECT COALESCE(array_agg(UPPER(trim(both '"' FROM elem))), ARRAY['HRMS','CRM','ERP'])
          FROM jsonb_array_elements_text(o.tag_line::jsonb) AS elem
        )
        ELSE string_to_array(upper(replace(o.tag_line, ' ', '')), ',')
      END
    )
  )
ON CONFLICT ("organization_id", "module_key") DO NOTHING;
