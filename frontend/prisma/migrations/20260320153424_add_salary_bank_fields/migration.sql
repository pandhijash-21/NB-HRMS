-- AlterTable
ALTER TABLE "employee_bank_info" ADD COLUMN     "bank_branch_code" TEXT;

-- AlterTable
ALTER TABLE "employee_salary_info" ADD COLUMN     "agp" DECIMAL(10,2),
ADD COLUMN     "gross_salary" DECIMAL(10,2);
