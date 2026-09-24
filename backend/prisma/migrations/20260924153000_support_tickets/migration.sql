-- CreateEnum
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED');

-- CreateTable
CREATE TABLE "support_tickets" (
    "id" TEXT NOT NULL,
    "ticket_no" TEXT NOT NULL,
    "employee_id" INTEGER NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "photo_url" TEXT,
    "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
    "eta_at" TIMESTAMP(3),
    "resolve_remarks" TEXT,
    "deny_remarks" TEXT,
    "force_closed" BOOLEAN NOT NULL DEFAULT false,
    "created_by" TEXT NOT NULL,
    "closed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_ticket_events" (
    "id" TEXT NOT NULL,
    "ticket_id" TEXT NOT NULL,
    "actor_id" TEXT NOT NULL,
    "from_status" "SupportTicketStatus",
    "to_status" "SupportTicketStatus" NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_ticket_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "support_tickets_ticket_no_key" ON "support_tickets"("ticket_no");

-- CreateIndex
CREATE INDEX "support_tickets_employee_id_status_idx" ON "support_tickets"("employee_id", "status");

-- CreateIndex
CREATE INDEX "support_tickets_status_created_at_idx" ON "support_tickets"("status", "created_at");

-- CreateIndex
CREATE INDEX "support_ticket_events_ticket_id_created_at_idx" ON "support_ticket_events"("ticket_id", "created_at");

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "employees"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_ticket_events" ADD CONSTRAINT "support_ticket_events_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
