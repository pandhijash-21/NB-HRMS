-- AlterTable crm_campaigns
ALTER TABLE "crm_campaigns" ADD COLUMN IF NOT EXISTS "assigned_telecaller_ids" INTEGER[] DEFAULT ARRAY[]::INTEGER[];
ALTER TABLE "crm_campaigns" ADD COLUMN IF NOT EXISTS "assignment_mode" TEXT DEFAULT 'ROUND_ROBIN';
