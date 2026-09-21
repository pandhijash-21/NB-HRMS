ALTER TABLE "employee_attendance_settings"
  ADD COLUMN IF NOT EXISTS "biometric_device_label" TEXT,
  ADD COLUMN IF NOT EXISTS "biometric_device_platform" TEXT;
