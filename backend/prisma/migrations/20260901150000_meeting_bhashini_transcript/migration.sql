-- Bhashini speech-to-text: per-speaker, time-stamped meeting conversation notes.
ALTER TABLE "meetings" ADD COLUMN "transcript_language" TEXT NOT NULL DEFAULT 'en';
ALTER TABLE "meetings" ADD COLUMN "conversation_text" TEXT;

CREATE TABLE "meeting_utterances" (
    "id" TEXT NOT NULL,
    "meeting_id" TEXT NOT NULL,
    "speaker_user_id" TEXT,
    "speaker_participant_id" TEXT,
    "speaker_name" TEXT NOT NULL,
    "spoken_at" TIMESTAMP(3) NOT NULL,
    "ended_at" TIMESTAMP(3),
    "text" TEXT NOT NULL,
    "language" TEXT NOT NULL DEFAULT 'en',
    "source" TEXT NOT NULL DEFAULT 'BHASHINI',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "meeting_utterances_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "meeting_utterances_meeting_id_spoken_at_idx" ON "meeting_utterances"("meeting_id", "spoken_at");

ALTER TABLE "meeting_utterances" ADD CONSTRAINT "meeting_utterances_meeting_id_fkey" FOREIGN KEY ("meeting_id") REFERENCES "meetings"("id") ON DELETE CASCADE ON UPDATE CASCADE;
