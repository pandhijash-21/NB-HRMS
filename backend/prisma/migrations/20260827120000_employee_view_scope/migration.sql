-- CreateEnum
CREATE TYPE "EmployeeViewScope" AS ENUM ('NONE', 'SELF', 'INSTITUTE', 'UNIVERSITY');

-- AlterTable
ALTER TABLE "role_permissions"
ADD COLUMN "employee_view_scope" "EmployeeViewScope" NOT NULL DEFAULT 'NONE';
