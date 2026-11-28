-- Vendor quotation portal (unique RFQ/PR invite link + OTP sessions)
ALTER TABLE "erp_purchase_settings"
ADD COLUMN IF NOT EXISTS "vendor_portal_enabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN IF NOT EXISTS "vendor_portal_auto_email" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "erp_purchase_quotations"
ADD COLUMN IF NOT EXISTS "vendor_email" TEXT,
ADD COLUMN IF NOT EXISTS "submitted_via_portal" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS "erp_purchase_vendor_invites" (
    "id" TEXT NOT NULL,
    "purchase_request_id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_purchase_vendor_invites_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_vendor_invites_purchase_request_id_key"
  ON "erp_purchase_vendor_invites"("purchase_request_id");
CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_vendor_invites_token_key"
  ON "erp_purchase_vendor_invites"("token");

CREATE TABLE IF NOT EXISTS "erp_purchase_vendor_otps" (
    "id" TEXT NOT NULL,
    "invite_id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "otp_hash" TEXT NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "cooldown_until" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "erp_purchase_vendor_otps_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_vendor_otps_invite_id_email_key"
  ON "erp_purchase_vendor_otps"("invite_id", "email");
CREATE INDEX IF NOT EXISTS "erp_purchase_vendor_otps_invite_id_idx"
  ON "erp_purchase_vendor_otps"("invite_id");

CREATE TABLE IF NOT EXISTS "erp_purchase_vendor_sessions" (
    "id" TEXT NOT NULL,
    "invite_id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "erp_purchase_vendor_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "erp_purchase_vendor_sessions_token_key"
  ON "erp_purchase_vendor_sessions"("token");
CREATE INDEX IF NOT EXISTS "erp_purchase_vendor_sessions_invite_id_email_idx"
  ON "erp_purchase_vendor_sessions"("invite_id", "email");

DO $$ BEGIN
  ALTER TABLE "erp_purchase_vendor_invites"
    ADD CONSTRAINT "erp_purchase_vendor_invites_purchase_request_id_fkey"
    FOREIGN KEY ("purchase_request_id") REFERENCES "erp_purchase_requests"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_purchase_vendor_otps"
    ADD CONSTRAINT "erp_purchase_vendor_otps_invite_id_fkey"
    FOREIGN KEY ("invite_id") REFERENCES "erp_purchase_vendor_invites"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "erp_purchase_vendor_sessions"
    ADD CONSTRAINT "erp_purchase_vendor_sessions_invite_id_fkey"
    FOREIGN KEY ("invite_id") REFERENCES "erp_purchase_vendor_invites"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
