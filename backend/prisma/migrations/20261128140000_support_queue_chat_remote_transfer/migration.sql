-- AlterEnum: Add QUEUED to SupportTicketStatus
ALTER TYPE "SupportTicketStatus" ADD VALUE IF NOT EXISTS 'QUEUED';

-- AlterTable: Add queue, assignment, and transfer columns to support_tickets
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "assigned_handler_id" INTEGER;
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "assigned_at" TIMESTAMP(3);
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "queue_position" INTEGER;
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "transfer_status" TEXT DEFAULT 'NONE';
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "transfer_target_handler_id" INTEGER;
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "transfer_reason" TEXT;
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "transfer_requested_by" TEXT;
ALTER TABLE "support_tickets" ADD COLUMN IF NOT EXISTS "transfer_requested_at" TIMESTAMP(3);

-- AlterTable: Add capacity and active status columns to support_it_assignees
ALTER TABLE "support_it_assignees" ADD COLUMN IF NOT EXISTS "max_concurrent_tickets" INTEGER NOT NULL DEFAULT 3;
ALTER TABLE "support_it_assignees" ADD COLUMN IF NOT EXISTS "is_active" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable: support_ticket_messages
CREATE TABLE IF NOT EXISTS "support_ticket_messages" (
    "id" TEXT NOT NULL,
    "ticket_id" TEXT NOT NULL,
    "sender_id" TEXT NOT NULL,
    "sender_role" TEXT NOT NULL,
    "sender_name" TEXT,
    "message" TEXT NOT NULL,
    "attachment_url" TEXT,
    "attachment_name" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "support_ticket_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable: support_remote_sessions
CREATE TABLE IF NOT EXISTS "support_remote_sessions" (
    "id" TEXT NOT NULL,
    "ticket_id" TEXT NOT NULL,
    "room_name" TEXT NOT NULL,
    "handler_user_id" TEXT NOT NULL,
    "employee_user_id" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'REQUESTED',
    "access_level" TEXT NOT NULL DEFAULT 'FULL_CONTROL',
    "uac_enabled" BOOLEAN NOT NULL DEFAULT true,
    "started_at" TIMESTAMP(3),
    "ended_at" TIMESTAMP(3),
    "ended_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "support_remote_sessions_pkey" PRIMARY KEY ("id")
);

-- Indexes
CREATE INDEX IF NOT EXISTS "support_tickets_assigned_handler_id_status_idx" ON "support_tickets"("assigned_handler_id", "status");
CREATE INDEX IF NOT EXISTS "support_ticket_messages_ticket_id_created_at_idx" ON "support_ticket_messages"("ticket_id", "created_at");
CREATE INDEX IF NOT EXISTS "support_remote_sessions_ticket_id_status_idx" ON "support_remote_sessions"("ticket_id", "status");

-- Foreign Keys
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'support_ticket_messages_ticket_id_fkey'
    ) THEN
        ALTER TABLE "support_ticket_messages" ADD CONSTRAINT "support_ticket_messages_ticket_id_fkey"
            FOREIGN KEY ("ticket_id") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'support_remote_sessions_ticket_id_fkey'
    ) THEN
        ALTER TABLE "support_remote_sessions" ADD CONSTRAINT "support_remote_sessions_ticket_id_fkey"
            FOREIGN KEY ("ticket_id") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;
