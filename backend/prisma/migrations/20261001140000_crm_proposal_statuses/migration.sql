-- AlterEnum: Add proposal, booking, and rejected statuses to CrmLeadStatus
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'PROPOSAL_SENT';
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'BOOKING_CONFIRMED';
ALTER TYPE "CrmLeadStatus" ADD VALUE IF NOT EXISTS 'REJECTED';
