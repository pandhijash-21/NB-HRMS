-- CreateTable
CREATE TABLE "department_approvers" (
    "id" TEXT NOT NULL,
    "department" TEXT NOT NULL,
    "hod_employee_id" INTEGER NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "department_approvers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "institute_approvers" (
    "id" TEXT NOT NULL,
    "institute" TEXT NOT NULL,
    "hoi_employee_id" INTEGER NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "institute_approvers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "global_approvers" (
    "id" TEXT NOT NULL,
    "vc_employee_id" INTEGER,
    "registrar_employee_id" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "global_approvers_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "department_approvers_department_key" ON "department_approvers"("department");

-- CreateIndex
CREATE UNIQUE INDEX "institute_approvers_institute_key" ON "institute_approvers"("institute");

-- AddForeignKey
ALTER TABLE "department_approvers" ADD CONSTRAINT "department_approvers_hod_employee_id_fkey" FOREIGN KEY ("hod_employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "institute_approvers" ADD CONSTRAINT "institute_approvers_hoi_employee_id_fkey" FOREIGN KEY ("hoi_employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "global_approvers" ADD CONSTRAINT "global_approvers_vc_employee_id_fkey" FOREIGN KEY ("vc_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "global_approvers" ADD CONSTRAINT "global_approvers_registrar_employee_id_fkey" FOREIGN KEY ("registrar_employee_id") REFERENCES "employees"("id") ON DELETE SET NULL ON UPDATE CASCADE;
