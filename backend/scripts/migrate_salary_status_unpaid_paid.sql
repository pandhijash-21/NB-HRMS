-- Rename SalaryRecordStatus DRAFT/FINALIZED → UNPAID/PAID
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'SalaryRecordStatus' AND e.enumlabel = 'DRAFT'
  ) THEN
    ALTER TYPE "SalaryRecordStatus" RENAME VALUE 'DRAFT' TO 'UNPAID';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON e.enumtypid = t.oid
    WHERE t.typname = 'SalaryRecordStatus' AND e.enumlabel = 'FINALIZED'
  ) THEN
    ALTER TYPE "SalaryRecordStatus" RENAME VALUE 'FINALIZED' TO 'PAID';
  END IF;
END $$;

ALTER TABLE "employee_salary_records" ALTER COLUMN "status" SET DEFAULT 'UNPAID'::"SalaryRecordStatus";
