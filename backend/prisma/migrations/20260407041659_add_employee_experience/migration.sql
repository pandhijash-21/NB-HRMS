-- CreateEnum
CREATE TYPE "ExperienceType" AS ENUM ('TEACHING', 'INDUSTRY', 'RESEARCH', 'ADMINISTRATIVE', 'CONSULTANCY', 'OTHER');

-- CreateTable
CREATE TABLE "employee_experience" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "type" "ExperienceType" NOT NULL,
    "designation" TEXT NOT NULL,
    "organization_name" TEXT NOT NULL,
    "from_date" DATE NOT NULL,
    "to_date" DATE NOT NULL,
    "job_description" TEXT,
    "last_salary" DECIMAL(12,2),
    "experience_letter_url" TEXT,
    "last_paycheck_url" TEXT,
    "recommendation_letters" JSONB NOT NULL DEFAULT '[]',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "employee_experience_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "employee_experience_employee_id_idx" ON "employee_experience"("employee_id");

-- AddForeignKey
ALTER TABLE "employee_experience" ADD CONSTRAINT "employee_experience_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;
