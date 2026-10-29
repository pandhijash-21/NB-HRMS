-- Task assignment acceptance + revised timeline workflow

DO $$ BEGIN
  ALTER TYPE "WorkTaskStatus" ADD VALUE 'TIMELINE_REVISION_REQUESTED';
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER TYPE "WorkTaskEventType" ADD VALUE 'ASSIGNMENT_ACCEPTED';
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER TYPE "WorkTaskEventType" ADD VALUE 'TIMELINE_REVISION_REQUESTED';
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  ALTER TYPE "WorkTaskEventType" ADD VALUE 'TIMELINE_REVISION_DECIDED';
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

ALTER TABLE "work_tasks"
  ADD COLUMN IF NOT EXISTS "proposed_deadline" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "proposed_deadline_remarks" TEXT;
