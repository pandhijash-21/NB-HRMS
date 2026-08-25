-- Durable email verification flags for first-login OTP gate
ALTER TABLE "employee_addresses"
  ADD COLUMN IF NOT EXISTS "personal_email_verified_at" TIMESTAMP(3),
  ADD COLUMN IF NOT EXISTS "institute_email_verified_at" TIMESTAMP(3);
