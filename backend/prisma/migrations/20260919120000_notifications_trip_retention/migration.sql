-- In-app notifications + tracking retention settings
CREATE TABLE IF NOT EXISTS "user_notifications" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "kind" TEXT NOT NULL DEFAULT 'announce',
    "path" TEXT,
    "sender_id" TEXT,
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "user_notifications_user_id_created_at_idx"
  ON "user_notifications"("user_id", "created_at");

CREATE INDEX IF NOT EXISTS "user_notifications_user_id_read_at_idx"
  ON "user_notifications"("user_id", "read_at");

CREATE TABLE IF NOT EXISTS "tracking_settings" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "description" TEXT,
    "updated_by" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "tracking_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "tracking_settings_key_key" ON "tracking_settings"("key");

INSERT INTO "tracking_settings" ("id", "key", "value", "description", "updated_by", "updated_at")
VALUES (
  gen_random_uuid()::text,
  'trip_retention_days',
  '90',
  'Closed trips older than this many days are deleted automatically. Set 0 to keep forever.',
  'migration',
  CURRENT_TIMESTAMP
)
ON CONFLICT ("key") DO NOTHING;
