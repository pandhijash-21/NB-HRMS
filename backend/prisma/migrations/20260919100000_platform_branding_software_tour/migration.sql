-- Splash / branding assets + first-login software tour flag
CREATE TABLE IF NOT EXISTS "platform_branding" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "meta" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "updated_by" TEXT,
    CONSTRAINT "platform_branding_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "platform_branding_key_key" ON "platform_branding"("key");

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "software_tour_seen_at" TIMESTAMP(3);
