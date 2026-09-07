-- AlterTable
ALTER TABLE "erp_machine_stock_logs" ADD COLUMN "contractor_id" TEXT,
ADD COLUMN "contractor_name" TEXT;

-- CreateIndex
CREATE INDEX "erp_machine_stock_logs_contractor_id_idx" ON "erp_machine_stock_logs"("contractor_id");

-- AddForeignKey
ALTER TABLE "erp_machine_stock_logs" ADD CONSTRAINT "erp_machine_stock_logs_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable
CREATE TABLE "erp_machine_issues" (
    "id" TEXT NOT NULL,
    "machine_id" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "contractor_name" TEXT,
    "quantity_taken" DECIMAL(14,4) NOT NULL,
    "quantity_returned" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "quantity_in_use" DECIMAL(14,4) NOT NULL DEFAULT 0,
    "issue_date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "erp_machine_issues_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "erp_machine_return_logs" (
    "id" TEXT NOT NULL,
    "machine_issue_id" TEXT NOT NULL,
    "machine_id" TEXT NOT NULL,
    "contractor_id" TEXT NOT NULL,
    "quantity_returned" DECIMAL(14,4) NOT NULL,
    "return_date" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "remarks" TEXT,
    "created_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "erp_machine_return_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "erp_machine_issues_machine_id_status_idx" ON "erp_machine_issues"("machine_id", "status");
CREATE INDEX "erp_machine_issues_contractor_id_status_idx" ON "erp_machine_issues"("contractor_id", "status");

-- CreateIndex
CREATE INDEX "erp_machine_return_logs_machine_issue_id_return_date_idx" ON "erp_machine_return_logs"("machine_issue_id", "return_date");
CREATE INDEX "erp_machine_return_logs_machine_id_idx" ON "erp_machine_return_logs"("machine_id");
CREATE INDEX "erp_machine_return_logs_contractor_id_idx" ON "erp_machine_return_logs"("contractor_id");

-- AddForeignKey
ALTER TABLE "erp_machine_issues" ADD CONSTRAINT "erp_machine_issues_machine_id_fkey" FOREIGN KEY ("machine_id") REFERENCES "erp_machines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machine_issues" ADD CONSTRAINT "erp_machine_issues_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "erp_machine_return_logs" ADD CONSTRAINT "erp_machine_return_logs_machine_issue_id_fkey" FOREIGN KEY ("machine_issue_id") REFERENCES "erp_machine_issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machine_return_logs" ADD CONSTRAINT "erp_machine_return_logs_machine_id_fkey" FOREIGN KEY ("machine_id") REFERENCES "erp_machines"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "erp_machine_return_logs" ADD CONSTRAINT "erp_machine_return_logs_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
