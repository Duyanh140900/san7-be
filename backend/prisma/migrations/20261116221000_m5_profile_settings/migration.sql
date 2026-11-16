-- CreateTable
CREATE TABLE "notification_settings" (
    "user_id" UUID NOT NULL,
    "match_updates" BOOLEAN NOT NULL DEFAULT true,
    "team_activity" BOOLEAN NOT NULL DEFAULT true,
    "community" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "notification_settings_pkey" PRIMARY KEY ("user_id")
);

ALTER TABLE "notification_settings" ADD CONSTRAINT "notification_settings_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
