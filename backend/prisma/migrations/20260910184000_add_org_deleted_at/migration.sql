-- AlterTable: safely add deleted_at to all tables
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'organizations') THEN
    ALTER TABLE "organizations" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'institutes') THEN
    ALTER TABLE "institutes" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'position_slots') THEN
    ALTER TABLE "position_slots" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'designations') THEN
    ALTER TABLE "designations" ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMP(3);
  END IF;
END $$;
