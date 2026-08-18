ALTER TABLE "employee_assignments" ADD COLUMN IF NOT EXISTS "change_type" TEXT;

DO $$ BEGIN
  CREATE TYPE "WorkTaskStatus" AS ENUM ('ASSIGNED', 'ONGOING', 'COMPLETED', 'CHANGES_REQUESTED', 'APPROVED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE "WorkTaskExtraApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE "WorkTaskEventType" AS ENUM ('CREATED', 'STATUS_CHANGED', 'EXTRA_APPROVAL_REQUESTED', 'EXTRA_APPROVAL_DECIDED', 'REVIEWED');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS "work_tasks" (
  "id" TEXT PRIMARY KEY,
  "title" TEXT NOT NULL,
  "description" TEXT,
  "status" "WorkTaskStatus" NOT NULL DEFAULT 'ASSIGNED',
  "assigner_user_id" TEXT NOT NULL,
  "assignee_user_id" TEXT NOT NULL,
  "assignee_employee_id" INTEGER NOT NULL,
  "deadline" TIMESTAMP(3) NOT NULL,
  "started_at" TIMESTAMP(3),
  "completed_at" TIMESTAMP(3),
  "reviewed_at" TIMESTAMP(3),
  "attachment_url" TEXT,
  "attachment_name" TEXT,
  "attachment_mime" TEXT,
  "extra_approver_user_id" TEXT,
  "extra_approval_status" "WorkTaskExtraApprovalStatus",
  "extra_approval_remarks" TEXT,
  "extra_approval_decided_at" TIMESTAMP(3),
  "review_remarks" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "work_tasks_assigner_user_id_fkey" FOREIGN KEY ("assigner_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "work_tasks_assignee_user_id_fkey" FOREIGN KEY ("assignee_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT "work_tasks_extra_approver_user_id_fkey" FOREIGN KEY ("extra_approver_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "work_tasks_assignee_employee_id_fkey" FOREIGN KEY ("assignee_employee_id") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "work_tasks_assigner_user_id_status_idx" ON "work_tasks"("assigner_user_id", "status");
CREATE INDEX IF NOT EXISTS "work_tasks_assignee_user_id_status_idx" ON "work_tasks"("assignee_user_id", "status");
CREATE INDEX IF NOT EXISTS "work_tasks_extra_approver_user_id_extra_approval_status_idx" ON "work_tasks"("extra_approver_user_id", "extra_approval_status");
CREATE INDEX IF NOT EXISTS "work_tasks_deadline_idx" ON "work_tasks"("deadline");

CREATE TABLE IF NOT EXISTS "work_task_events" (
  "id" TEXT PRIMARY KEY,
  "task_id" TEXT NOT NULL,
  "actor_user_id" TEXT NOT NULL,
  "type" "WorkTaskEventType" NOT NULL,
  "from_status" "WorkTaskStatus",
  "to_status" "WorkTaskStatus",
  "remarks" TEXT,
  "new_deadline" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "work_task_events_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "work_tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "work_task_events_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "work_task_events_task_id_created_at_idx" ON "work_task_events"("task_id", "created_at");
