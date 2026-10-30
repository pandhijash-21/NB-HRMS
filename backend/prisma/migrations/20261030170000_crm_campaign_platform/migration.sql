-- AlterTable
ALTER TABLE "crm_campaigns" ADD COLUMN IF NOT EXISTS "platform" TEXT NOT NULL DEFAULT 'WEBHOOK';

-- CreateIndex
CREATE INDEX IF NOT EXISTS "crm_campaigns_platform_idx" ON "crm_campaigns"("platform");
