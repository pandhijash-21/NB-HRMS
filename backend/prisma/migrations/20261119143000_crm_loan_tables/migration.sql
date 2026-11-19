-- NB Capital / Finserve loan pipeline dedicated tables

CREATE TABLE IF NOT EXISTS "crm_loan_applications" (
    "id" TEXT NOT NULL,
    "lead_id" TEXT NOT NULL,
    "loan_type" TEXT,
    "loan_stage" TEXT,
    "application_details" JSONB NOT NULL DEFAULT '{}',
    "forwarded_to_id" INTEGER,
    "forwarded_to_name" TEXT,
    "forwarded_at" TIMESTAMP(3),
    "forwarded_by" TEXT,
    "forwarded_remarks" TEXT,
    "final_bank_name" TEXT,
    "final_bank_roi" TEXT,
    "final_bank_application_id" TEXT,
    "final_bank_id" TEXT,
    "loan_agreement_number" TEXT,
    "finalized_at" TIMESTAMP(3),
    "finalized_by" TEXT,
    "current_tentative_date" TIMESTAMP(3),
    "is_disbursed" BOOLEAN NOT NULL DEFAULT false,
    "disbursed_at" TIMESTAMP(3),
    "disbursed_amount" TEXT,
    "disbursement_remarks" TEXT,
    "flow_closed" BOOLEAN NOT NULL DEFAULT false,
    "portal_token" TEXT,
    "portal_link" TEXT,
    "client_portal_status" TEXT NOT NULL DEFAULT 'DRAFT',
    "client_portal_submitted_at" TIMESTAMP(3),
    "client_portal_confirmed" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_loan_applications_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "crm_loan_applications_lead_id_key" ON "crm_loan_applications"("lead_id");
CREATE UNIQUE INDEX IF NOT EXISTS "crm_loan_applications_portal_token_key" ON "crm_loan_applications"("portal_token");
CREATE INDEX IF NOT EXISTS "crm_loan_applications_loan_stage_idx" ON "crm_loan_applications"("loan_stage");
CREATE INDEX IF NOT EXISTS "crm_loan_applications_client_portal_status_idx" ON "crm_loan_applications"("client_portal_status");

CREATE TABLE IF NOT EXISTS "crm_loan_bank_applications" (
    "id" TEXT NOT NULL,
    "loan_application_id" TEXT NOT NULL,
    "bank_name" TEXT NOT NULL,
    "applied_at" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "rejection_remarks" TEXT,
    "roi" TEXT,
    "approved_amount" TEXT,
    "tenure_months" TEXT,
    "is_final_selected" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_loan_bank_applications_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "crm_loan_bank_applications_loan_application_id_idx" ON "crm_loan_bank_applications"("loan_application_id");
CREATE INDEX IF NOT EXISTS "crm_loan_bank_applications_status_idx" ON "crm_loan_bank_applications"("status");

CREATE TABLE IF NOT EXISTS "crm_loan_bank_queries" (
    "id" TEXT NOT NULL,
    "loan_application_id" TEXT NOT NULL,
    "stage" TEXT DEFAULT 'General',
    "query" TEXT NOT NULL,
    "required" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "raised_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "raised_by" TEXT,
    "resolved_at" TIMESTAMP(3),
    "resolved_by" TEXT,
    "resolution_notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_loan_bank_queries_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "crm_loan_bank_queries_loan_application_id_idx" ON "crm_loan_bank_queries"("loan_application_id");
CREATE INDEX IF NOT EXISTS "crm_loan_bank_queries_status_idx" ON "crm_loan_bank_queries"("status");

CREATE TABLE IF NOT EXISTS "crm_loan_documents" (
    "id" TEXT NOT NULL,
    "loan_application_id" TEXT NOT NULL,
    "doc_type_id" TEXT NOT NULL,
    "doc_name" TEXT NOT NULL,
    "file_url" TEXT NOT NULL,
    "file_name" TEXT NOT NULL,
    "file_size" INTEGER,
    "uploaded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "uploaded_by" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "source" TEXT NOT NULL DEFAULT 'agent',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_loan_documents_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "crm_loan_documents_loan_application_id_idx" ON "crm_loan_documents"("loan_application_id");
CREATE INDEX IF NOT EXISTS "crm_loan_documents_doc_type_id_idx" ON "crm_loan_documents"("doc_type_id");

CREATE TABLE IF NOT EXISTS "crm_loan_tentative_dates" (
    "id" TEXT NOT NULL,
    "loan_application_id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "set_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "set_by" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PENDING',
    "delay_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "crm_loan_tentative_dates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "crm_loan_tentative_dates_loan_application_id_idx" ON "crm_loan_tentative_dates"("loan_application_id");

ALTER TABLE "crm_loan_applications"
  ADD CONSTRAINT "crm_loan_applications_lead_id_fkey"
  FOREIGN KEY ("lead_id") REFERENCES "crm_leads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "crm_loan_bank_applications"
  ADD CONSTRAINT "crm_loan_bank_applications_loan_application_id_fkey"
  FOREIGN KEY ("loan_application_id") REFERENCES "crm_loan_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "crm_loan_bank_queries"
  ADD CONSTRAINT "crm_loan_bank_queries_loan_application_id_fkey"
  FOREIGN KEY ("loan_application_id") REFERENCES "crm_loan_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "crm_loan_documents"
  ADD CONSTRAINT "crm_loan_documents_loan_application_id_fkey"
  FOREIGN KEY ("loan_application_id") REFERENCES "crm_loan_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "crm_loan_tentative_dates"
  ADD CONSTRAINT "crm_loan_tentative_dates_loan_application_id_fkey"
  FOREIGN KEY ("loan_application_id") REFERENCES "crm_loan_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
