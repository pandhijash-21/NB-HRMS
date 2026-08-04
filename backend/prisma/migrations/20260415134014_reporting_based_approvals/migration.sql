/*
  Warnings:

  - You are about to drop the column `first_reporting` on the `employee_general_info` table. All the data in the column will be lost.
  - You are about to drop the column `second_reporting` on the `employee_general_info` table. All the data in the column will be lost.
  - You are about to drop the column `third_reporting` on the `employee_general_info` table. All the data in the column will be lost.

*/
-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "ApproverRole" ADD VALUE 'FIRST_REPORTING';
ALTER TYPE "ApproverRole" ADD VALUE 'SECOND_REPORTING';
ALTER TYPE "ApproverRole" ADD VALUE 'THIRD_REPORTING';

-- AlterTable
ALTER TABLE "employee_general_info" DROP COLUMN "first_reporting",
DROP COLUMN "second_reporting",
DROP COLUMN "third_reporting",
ADD COLUMN     "first_reporting_id" INTEGER,
ADD COLUMN     "second_reporting_id" INTEGER,
ADD COLUMN     "third_reporting_id" INTEGER;

-- AddForeignKey
ALTER TABLE "employee_general_info" ADD CONSTRAINT "employee_general_info_first_reporting_id_fkey" FOREIGN KEY ("first_reporting_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_general_info" ADD CONSTRAINT "employee_general_info_second_reporting_id_fkey" FOREIGN KEY ("second_reporting_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_general_info" ADD CONSTRAINT "employee_general_info_third_reporting_id_fkey" FOREIGN KEY ("third_reporting_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
