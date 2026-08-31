-- Idempotent: production may have created the enum/column before Prisma
-- recorded success (health-check timeout / container restart).
DO $$ BEGIN
  CREATE TYPE "EmployeeViewScope" AS ENUM ('NONE', 'SELF', 'INSTITUTE', 'UNIVERSITY');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "role_permissions"
ADD COLUMN IF NOT EXISTS "employee_view_scope" "EmployeeViewScope" NOT NULL DEFAULT 'NONE';
