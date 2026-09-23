-- Family emergency contact + pay commission payable days mode

ALTER TABLE "family_members" ADD COLUMN IF NOT EXISTS "is_emergency_contact" BOOLEAN NOT NULL DEFAULT false;

DO $$ BEGIN
  CREATE TYPE "PayableDaysMode" AS ENUM ('WORKING_DAYS_26_27', 'CALENDAR_30_31');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "pay_commissions" ADD COLUMN IF NOT EXISTS "payable_days_mode" "PayableDaysMode" NOT NULL DEFAULT 'WORKING_DAYS_26_27';
