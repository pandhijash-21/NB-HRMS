-- Reimbursement types, dynamic fields, claim values, apply-on-behalf

DO $$ BEGIN
  CREATE TYPE "ReimbursementAmountMode" AS ENUM ('KM_RATE', 'MANUAL');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "ReimbursementFieldKind" AS ENUM ('TEXT', 'NUMBER', 'KM_OPENING', 'KM_CLOSING', 'DATE', 'FILE', 'AMOUNT');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "reimbursement_types" (
  "id" TEXT PRIMARY KEY,
  "code" TEXT NOT NULL UNIQUE,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "amount_mode" "ReimbursementAmountMode" NOT NULL DEFAULT 'KM_RATE',
  "rate_per_unit" DECIMAL(12,4),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "reimbursement_field_defs" (
  "id" TEXT PRIMARY KEY,
  "type_id" TEXT NOT NULL,
  "key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "field_kind" "ReimbursementFieldKind" NOT NULL,
  "requires_proof" BOOLEAN NOT NULL DEFAULT false,
  "is_required" BOOLEAN NOT NULL DEFAULT true,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "reimbursement_field_defs_type_id_fkey"
    FOREIGN KEY ("type_id") REFERENCES "reimbursement_types"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "reimbursement_field_defs_type_id_key_key"
  ON "reimbursement_field_defs"("type_id", "key");
CREATE INDEX IF NOT EXISTS "reimbursement_field_defs_type_id_sort_order_idx"
  ON "reimbursement_field_defs"("type_id", "sort_order");

ALTER TABLE "reimbursement_claims" ADD COLUMN IF NOT EXISTS "type_id" TEXT;
ALTER TABLE "reimbursement_claims" ADD COLUMN IF NOT EXISTS "claim_date" DATE;
ALTER TABLE "reimbursement_claims" ADD COLUMN IF NOT EXISTS "on_behalf_by" TEXT;

DO $$ BEGIN
  ALTER TABLE "reimbursement_claims"
    ADD CONSTRAINT "reimbursement_claims_type_id_fkey"
    FOREIGN KEY ("type_id") REFERENCES "reimbursement_types"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS "reimbursement_claims_type_id_idx" ON "reimbursement_claims"("type_id");

CREATE TABLE IF NOT EXISTS "reimbursement_claim_values" (
  "id" TEXT PRIMARY KEY,
  "claim_id" TEXT NOT NULL,
  "field_def_id" TEXT NOT NULL,
  "value_text" TEXT,
  "value_number" DOUBLE PRECISION,
  "proof_url" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "reimbursement_claim_values_claim_id_fkey"
    FOREIGN KEY ("claim_id") REFERENCES "reimbursement_claims"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "reimbursement_claim_values_field_def_id_fkey"
    FOREIGN KEY ("field_def_id") REFERENCES "reimbursement_field_defs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "reimbursement_claim_values_claim_id_field_def_id_key"
  ON "reimbursement_claim_values"("claim_id", "field_def_id");
CREATE INDEX IF NOT EXISTS "reimbursement_claim_values_claim_id_idx"
  ON "reimbursement_claim_values"("claim_id");

-- Seed Fuel type
INSERT INTO "reimbursement_types" ("id", "code", "name", "description", "amount_mode", "rate_per_unit", "is_active", "sort_order", "created_at", "updated_at")
VALUES (
  'seed-reim-type-fuel',
  'FUEL',
  'Fuel',
  'Travel fuel reimbursement based on opening/closing km',
  'KM_RATE',
  10.0000,
  true,
  1,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
)
ON CONFLICT ("code") DO UPDATE SET
  "name" = EXCLUDED."name",
  "amount_mode" = EXCLUDED."amount_mode",
  "is_active" = true;

INSERT INTO "reimbursement_field_defs" ("id", "type_id", "key", "label", "field_kind", "requires_proof", "is_required", "sort_order", "created_at", "updated_at")
SELECT 'seed-reim-field-open-km', t."id", 'opening_km', 'Opening km', 'KM_OPENING', true, true, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "reimbursement_types" t WHERE t."code" = 'FUEL'
ON CONFLICT ("type_id", "key") DO UPDATE SET "label" = EXCLUDED."label", "field_kind" = EXCLUDED."field_kind";

INSERT INTO "reimbursement_field_defs" ("id", "type_id", "key", "label", "field_kind", "requires_proof", "is_required", "sort_order", "created_at", "updated_at")
SELECT 'seed-reim-field-close-km', t."id", 'closing_km', 'Closing km', 'KM_CLOSING', true, true, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "reimbursement_types" t WHERE t."code" = 'FUEL'
ON CONFLICT ("type_id", "key") DO UPDATE SET "label" = EXCLUDED."label", "field_kind" = EXCLUDED."field_kind";
