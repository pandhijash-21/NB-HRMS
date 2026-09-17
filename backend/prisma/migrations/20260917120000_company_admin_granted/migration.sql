-- Super Admin can grant System Admin privileges to an existing employee
-- without changing their designation (e.g. HR HEAD stays HR HEAD).
ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "company_admin_granted" BOOLEAN NOT NULL DEFAULT false;
