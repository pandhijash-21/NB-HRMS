-- Idempotent so a retry after a failed previous migration is safe.
DO $$ BEGIN
  CREATE TYPE "MeetingAdmission" AS ENUM ('WAITING', 'ADMITTED', 'DENIED');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "meeting_participants"
ADD COLUMN IF NOT EXISTS "admission" "MeetingAdmission" NOT NULL DEFAULT 'ADMITTED';
