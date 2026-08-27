DO $$ BEGIN
  ALTER TYPE "WorkTaskEventType" ADD VALUE IF NOT EXISTS 'SUBTASK_UPDATED';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "work_task_subtasks" (
  "id" TEXT PRIMARY KEY,
  "task_id" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "is_done" BOOLEAN NOT NULL DEFAULT FALSE,
  "completed_at" TIMESTAMP(3),
  "attachment_url" TEXT,
  "attachment_name" TEXT,
  "attachment_mime" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "work_task_subtasks_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "work_tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "work_task_subtasks_task_id_sort_order_idx" ON "work_task_subtasks"("task_id", "sort_order");
