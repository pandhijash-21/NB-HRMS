-- CreateEnum
CREATE TYPE "LeaveApplicableTo" AS ENUM ('TEACHING', 'NON_TEACHING', 'BOTH');

-- CreateEnum
CREATE TYPE "LeaveApplicationStatus" AS ENUM ('PENDING', 'HOD_RECOMMENDED', 'HOI_RECOMMENDED', 'APPROVED', 'REJECTED', 'CANCELLED', 'AUTO_LWP');

-- CreateEnum
CREATE TYPE "HalfDaySession" AS ENUM ('MORNING', 'AFTERNOON');

-- CreateEnum
CREATE TYPE "ApproverRole" AS ENUM ('HOD', 'HOI', 'VC', 'REGISTRAR');

-- CreateEnum
CREATE TYPE "ApprovalAction" AS ENUM ('RECOMMENDED', 'REJECTED', 'APPROVED');

-- CreateTable
CREATE TABLE "leave_types" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "applicable_to" "LeaveApplicableTo" NOT NULL,
    "default_days_per_year" DOUBLE PRECISION,
    "is_carry_forward" BOOLEAN NOT NULL DEFAULT false,
    "allow_half_day" BOOLEAN NOT NULL DEFAULT true,
    "skip_public_holidays" BOOLEAN NOT NULL DEFAULT true,
    "skip_weekends" BOOLEAN NOT NULL DEFAULT true,
    "requires_document" BOOLEAN NOT NULL DEFAULT false,
    "requires_reason" BOOLEAN NOT NULL DEFAULT true,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "credit_schedule" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leave_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_balances" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "leave_type_id" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "total_credited" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "carry_forward" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "used" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "pending" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "available" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "last_credited_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leave_balances_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_applications" (
    "id" TEXT NOT NULL,
    "application_no" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "leave_type_id" TEXT NOT NULL,
    "from_date" TIMESTAMP(3) NOT NULL,
    "to_date" TIMESTAMP(3) NOT NULL,
    "is_half_day" BOOLEAN NOT NULL DEFAULT false,
    "half_day_session" "HalfDaySession",
    "total_days" DOUBLE PRECISION NOT NULL,
    "reason" TEXT NOT NULL,
    "document_url" TEXT,
    "status" "LeaveApplicationStatus" NOT NULL DEFAULT 'PENDING',
    "applied_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_absence_linked" BOOLEAN NOT NULL DEFAULT false,
    "absence_date" TIMESTAMP(3),
    "absence_window_expires_at" TIMESTAMP(3),
    "applied_by" TEXT NOT NULL,
    "is_applied_by_admin" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leave_applications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_approval_steps" (
    "id" TEXT NOT NULL,
    "application_id" TEXT NOT NULL,
    "step_number" INTEGER NOT NULL,
    "approver_role" "ApproverRole" NOT NULL,
    "approver_id" INTEGER,
    "action" "ApprovalAction",
    "remarks" TEXT,
    "action_at" TIMESTAMP(3),
    "window_expires_at" TIMESTAMP(3),
    "notified_at" TIMESTAMP(3),
    "is_superseded" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "leave_approval_steps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "absence_records" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "marked_at" TIMESTAMP(3) NOT NULL,
    "window_expires_at" TIMESTAMP(3) NOT NULL,
    "leave_application_id" TEXT,
    "converted_to_lwp" BOOLEAN NOT NULL DEFAULT false,
    "bullmq_job_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "absence_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public_holidays" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "year" INTEGER NOT NULL,
    "is_optional" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "public_holidays_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_settings" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "updated_by" TEXT NOT NULL,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "leave_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "leave_audit_log" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER,
    "actor_id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "context" TEXT,
    "oldValue" JSONB,
    "newValue" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "leave_audit_log_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "monthly_lwp_records" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "year" INTEGER NOT NULL,
    "month" INTEGER NOT NULL,
    "days" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "monthly_lwp_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "leave_types_code_key" ON "leave_types"("code");

-- CreateIndex
CREATE UNIQUE INDEX "leave_balances_employee_id_leave_type_id_year_key" ON "leave_balances"("employee_id", "leave_type_id", "year");

-- CreateIndex
CREATE UNIQUE INDEX "leave_applications_application_no_key" ON "leave_applications"("application_no");

-- CreateIndex
CREATE UNIQUE INDEX "leave_settings_key_key" ON "leave_settings"("key");

-- CreateIndex
CREATE INDEX "leave_audit_log_employee_id_idx" ON "leave_audit_log"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "monthly_lwp_records_employee_id_year_month_key" ON "monthly_lwp_records"("employee_id", "year", "month");

-- AddForeignKey
ALTER TABLE "leave_balances" ADD CONSTRAINT "leave_balances_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_balances" ADD CONSTRAINT "leave_balances_leave_type_id_fkey" FOREIGN KEY ("leave_type_id") REFERENCES "leave_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_applications" ADD CONSTRAINT "leave_applications_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_applications" ADD CONSTRAINT "leave_applications_leave_type_id_fkey" FOREIGN KEY ("leave_type_id") REFERENCES "leave_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_approval_steps" ADD CONSTRAINT "leave_approval_steps_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "leave_applications"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "absence_records" ADD CONSTRAINT "absence_records_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "absence_records" ADD CONSTRAINT "absence_records_leave_application_id_fkey" FOREIGN KEY ("leave_application_id") REFERENCES "leave_applications"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "leave_audit_log" ADD CONSTRAINT "leave_audit_log_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "monthly_lwp_records" ADD CONSTRAINT "monthly_lwp_records_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
