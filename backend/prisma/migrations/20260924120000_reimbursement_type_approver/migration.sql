-- Who approves claims for each reimbursement type
ALTER TABLE "reimbursement_types"
  ADD COLUMN IF NOT EXISTS "approver_user_id" TEXT;

CREATE INDEX IF NOT EXISTS "reimbursement_types_approver_user_id_idx"
  ON "reimbursement_types"("approver_user_id");
