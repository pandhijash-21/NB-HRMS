-- CreateTable
CREATE TABLE "employee_salary_info" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "pay_commission" TEXT,
    "pay_grade" TEXT,
    "basic_salary" DECIMAL(10,2),
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
    "ifsc_code" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,

    CONSTRAINT "employee_bank_info_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "employee_salary_info_employee_id_key" ON "employee_salary_info"("employee_id");

-- CreateIndex
CREATE UNIQUE INDEX "employee_bank_info_employee_id_key" ON "employee_bank_info"("employee_id");

-- AddForeignKey
ALTER TABLE "employee_salary_info" ADD CONSTRAINT "employee_salary_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "employee_bank_info" ADD CONSTRAINT "employee_bank_info_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
