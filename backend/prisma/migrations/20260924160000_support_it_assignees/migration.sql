-- CreateTable
CREATE TABLE "support_it_assignees" (
    "id" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_it_assignees_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "support_it_assignees_employee_id_key" ON "support_it_assignees"("employee_id");

-- AddForeignKey
ALTER TABLE "support_it_assignees" ADD CONSTRAINT "support_it_assignees_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;
