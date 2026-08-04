/*
  Warnings:

  - A unique constraint covering the columns `[employee_code]` on the table `employee_general_info` will be added. If there are existing duplicate values, this will fail.

*/
-- CreateEnum
CREATE TYPE "RequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- AlterTable
ALTER TABLE "academic_qualifications" ADD COLUMN     "deleted_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "employee_general_info" ADD COLUMN     "employee_code" TEXT;

-- AlterTable
ALTER TABLE "family_members" ADD COLUMN     "deleted_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "change_requests" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "module" TEXT NOT NULL,
    "old_data" JSONB,
    "new_data" JSONB NOT NULL,
    "status" "RequestStatus" NOT NULL DEFAULT 'PENDING',
    "requested_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_by" TEXT,
    "reviewed_at" TIMESTAMP(3),

    CONSTRAINT "change_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_salary_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "pay_commission" TEXT,
    "pay_grade" TEXT,
    "basic_salary" DECIMAL(12,2),
    "agp" DECIMAL(12,2),
    "gross_salary" DECIMAL(12,2),
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_salary_info_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "employee_bank_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "bank_name" TEXT,
    "bank_account_no" TEXT,
    "bank_branch_code" TEXT,
    "ifsc_code" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_bank_info_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "employee_salary_info_employee_id_key" ON "employee_salary_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_bank_info_employee_id_key" ON "employee_bank_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_general_info_employee_code_key" ON "employee_general_info"("employee_code");

-- AddForeignKey
ALTER TABLE "change_requests" ADD CONSTRAINT "change_requests_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_salary_info" ADD CONSTRAINT "employee_salary_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_bank_info" ADD CONSTRAINT "employee_bank_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
