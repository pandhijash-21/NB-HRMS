-- AlterTable
ALTER TABLE "erp_material_stock_logs" ADD COLUMN "contractor_id" TEXT,
ADD COLUMN "contractor_name" TEXT;

-- CreateIndex
CREATE INDEX "erp_material_stock_logs_contractor_id_idx" ON "erp_material_stock_logs"("contractor_id");

-- AddForeignKey
ALTER TABLE "erp_material_stock_logs" ADD CONSTRAINT "erp_material_stock_logs_contractor_id_fkey" FOREIGN KEY ("contractor_id") REFERENCES "erp_contractors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
