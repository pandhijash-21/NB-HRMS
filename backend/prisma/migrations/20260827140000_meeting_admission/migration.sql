-- CreateEnum
CREATE TYPE "MeetingAdmission" AS ENUM ('WAITING', 'ADMITTED', 'DENIED');

-- AlterTable
ALTER TABLE "meeting_participants"
ADD COLUMN "admission" "MeetingAdmission" NOT NULL DEFAULT 'ADMITTED';
