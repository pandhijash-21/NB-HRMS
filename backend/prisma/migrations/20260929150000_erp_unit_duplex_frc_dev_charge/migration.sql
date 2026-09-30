-- Add is_duplex, frc, and development_charge columns to erp_project_units
ALTER TABLE "erp_project_units"
  ADD COLUMN IF NOT EXISTS "is_duplex" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "frc" DECIMAL(14,2),
  ADD COLUMN IF NOT EXISTS "development_charge" DECIMAL(14,2);
