-- AlterTable crm_projects
ALTER TABLE "crm_projects" ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'NB_DEVELOPER';
CREATE INDEX IF NOT EXISTS "crm_projects_scope_idx" ON "crm_projects"("scope");

-- AlterTable crm_campaigns
ALTER TABLE "crm_campaigns" ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'NB_DEVELOPER';
CREATE INDEX IF NOT EXISTS "crm_campaigns_scope_idx" ON "crm_campaigns"("scope");

-- AlterTable crm_leads
ALTER TABLE "crm_leads" ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'NB_DEVELOPER';
CREATE INDEX IF NOT EXISTS "crm_leads_scope_idx" ON "crm_leads"("scope");

-- AlterTable crm_column_configs
ALTER TABLE "crm_column_configs" ADD COLUMN IF NOT EXISTS "scope" TEXT NOT NULL DEFAULT 'NB_DEVELOPER';
CREATE INDEX IF NOT EXISTS "crm_column_configs_scope_idx" ON "crm_column_configs"("scope");

-- Update unique constraint on crm_column_configs to include scope
DO $$ BEGIN
  ALTER TABLE "crm_column_configs" DROP CONSTRAINT IF EXISTS "crm_column_configs_module_campaign_id_column_key_key";
  DROP INDEX IF EXISTS "crm_column_configs_module_campaign_id_column_key_key";
EXCEPTION WHEN undefined_object THEN NULL; END $$;

CREATE UNIQUE INDEX IF NOT EXISTS "crm_column_configs_module_campaign_id_column_key_scope_key"
  ON "crm_column_configs"("module", "campaign_id", "column_key", "scope");
