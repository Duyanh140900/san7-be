-- CreateEnum
CREATE TYPE "PostScheduleStatus" AS ENUM ('scheduled', 'cancelled');

-- CreateTable
CREATE TABLE "post_schedules" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "team_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "payload" JSONB NOT NULL,
    "scheduled_at" TIMESTAMPTZ(6) NOT NULL,
    "repeat_weekly" BOOLEAN NOT NULL DEFAULT false,
    "status" "PostScheduleStatus" NOT NULL DEFAULT 'scheduled',
    "published_post_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "post_schedules_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "post_schedules_published_post_id_key" ON "post_schedules"("published_post_id");
CREATE INDEX "post_schedules_team_id_status_scheduled_at_idx" ON "post_schedules"("team_id", "status", "scheduled_at");
CREATE INDEX "post_schedules_author_id_status_scheduled_at_idx" ON "post_schedules"("author_id", "status", "scheduled_at");

ALTER TABLE "post_schedules" ADD CONSTRAINT "post_schedules_team_id_fkey"
  FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "post_schedules" ADD CONSTRAINT "post_schedules_author_id_fkey"
  FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "post_schedules" ADD CONSTRAINT "post_schedules_published_post_id_fkey"
  FOREIGN KEY ("published_post_id") REFERENCES "posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
