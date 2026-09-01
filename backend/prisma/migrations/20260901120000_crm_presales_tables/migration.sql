-- CRM pre-sales tables (idempotent so existing Hostinger data is kept).

DO $$ BEGIN
  CREATE TYPE "CrmLeadStatus" AS ENUM ('NOT_STARTED', 'FOLLOW_UP', 'INTERESTED', 'NOT_INTERESTED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS crm_projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    description TEXT,
    location TEXT,
    start_date TIMESTAMP(3),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS crm_campaigns (
    id TEXT PRIMARY KEY,
    project_id TEXT REFERENCES crm_projects(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    ad_id TEXT,
    webhook_token TEXT UNIQUE,
    description TEXT,
    start_date TIMESTAMP(3),
    module TEXT NOT NULL DEFAULT 'PRE_SALES',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE crm_campaigns ADD COLUMN IF NOT EXISTS project_id TEXT;
ALTER TABLE crm_campaigns ADD COLUMN IF NOT EXISTS ad_id TEXT;
ALTER TABLE crm_campaigns ADD COLUMN IF NOT EXISTS webhook_token TEXT;

CREATE TABLE IF NOT EXISTS crm_column_configs (
    id TEXT PRIMARY KEY,
    module TEXT NOT NULL DEFAULT 'PRE_SALES',
    campaign_id TEXT REFERENCES crm_campaigns(id) ON DELETE CASCADE,
    column_key TEXT NOT NULL,
    label TEXT NOT NULL,
    data_type TEXT NOT NULL DEFAULT 'TEXT',
    options TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    is_required BOOLEAN NOT NULL DEFAULT false,
    is_system BOOLEAN NOT NULL DEFAULT false,
    is_visible_in_table BOOLEAN NOT NULL DEFAULT true,
    is_merged BOOLEAN NOT NULL DEFAULT false,
    merged_into_key TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (module, campaign_id, column_key)
);

ALTER TABLE crm_column_configs ADD COLUMN IF NOT EXISTS is_visible_in_table BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE crm_column_configs ADD COLUMN IF NOT EXISTS is_merged BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE crm_column_configs ADD COLUMN IF NOT EXISTS merged_into_key TEXT;

CREATE TABLE IF NOT EXISTS crm_leads (
    id TEXT PRIMARY KEY,
    campaign_id TEXT REFERENCES crm_campaigns(id) ON DELETE SET NULL,
    phone TEXT NOT NULL,
    name TEXT,
    status "CrmLeadStatus" NOT NULL DEFAULT 'NOT_STARTED',
    custom_fields JSONB NOT NULL DEFAULT '{}'::jsonb,
    assigned_to_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    telecaller_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    created_by_id TEXT,
    last_call_at TIMESTAMP(3),
    not_interested_at TIMESTAMP(3),
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    deleted_at TIMESTAMP(3),
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS crm_leads_campaign_id_idx ON crm_leads (campaign_id);
CREATE INDEX IF NOT EXISTS crm_leads_status_idx ON crm_leads (status);
CREATE INDEX IF NOT EXISTS crm_leads_phone_idx ON crm_leads (phone);
CREATE INDEX IF NOT EXISTS crm_leads_is_deleted_idx ON crm_leads (is_deleted);
CREATE INDEX IF NOT EXISTS crm_leads_assigned_to_id_idx ON crm_leads (assigned_to_id);
CREATE INDEX IF NOT EXISTS crm_leads_telecaller_id_idx ON crm_leads (telecaller_id);

CREATE TABLE IF NOT EXISTS crm_follow_ups (
    id TEXT PRIMARY KEY,
    lead_id TEXT NOT NULL REFERENCES crm_leads(id) ON DELETE CASCADE,
    scheduled_date TIMESTAMP(3) NOT NULL,
    scheduled_time TEXT NOT NULL,
    remarks TEXT,
    status TEXT NOT NULL DEFAULT 'PENDING',
    created_by_id TEXT,
    assigned_to_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS crm_follow_ups_lead_id_idx ON crm_follow_ups (lead_id);
CREATE INDEX IF NOT EXISTS crm_follow_ups_scheduled_date_idx ON crm_follow_ups (scheduled_date);
CREATE INDEX IF NOT EXISTS crm_follow_ups_status_idx ON crm_follow_ups (status);

CREATE TABLE IF NOT EXISTS crm_call_logs (
    id TEXT PRIMARY KEY,
    lead_id TEXT REFERENCES crm_leads(id) ON DELETE SET NULL,
    customer_number TEXT NOT NULL,
    agent_number TEXT,
    did TEXT,
    call_status TEXT,
    duration INTEGER DEFAULT 0,
    recording_url TEXT,
    call_time TIMESTAMP(3),
    call_id TEXT,
    raw_payload JSONB,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS crm_call_logs_customer_number_idx ON crm_call_logs (customer_number);
CREATE INDEX IF NOT EXISTS crm_call_logs_lead_id_idx ON crm_call_logs (lead_id);
CREATE INDEX IF NOT EXISTS crm_call_logs_call_status_idx ON crm_call_logs (call_status);

CREATE TABLE IF NOT EXISTS crm_settings (
    id TEXT PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_by TEXT,
    updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
