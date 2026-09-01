-- Allow in-meet DMs to address guests (and any participant) by participant id,
-- not only logged-in user ids.
ALTER TABLE "meeting_chat_messages" ADD COLUMN "sender_participant_id" TEXT;
ALTER TABLE "meeting_chat_messages" ADD COLUMN "recipient_participant_id" TEXT;

CREATE INDEX "meeting_chat_messages_sender_participant_id_idx" ON "meeting_chat_messages"("sender_participant_id");
CREATE INDEX "meeting_chat_messages_recipient_participant_id_idx" ON "meeting_chat_messages"("recipient_participant_id");
