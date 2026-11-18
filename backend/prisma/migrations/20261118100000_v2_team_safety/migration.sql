CREATE TABLE "team_reports" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "reporter_team_id" UUID NOT NULL,
  "reported_team_id" UUID NOT NULL,
  "match_id" UUID,
  "reason" TEXT NOT NULL,
  "description" TEXT,
  "image_keys" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "created_by" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "team_reports_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "team_reports_reporter_team_id_fkey" FOREIGN KEY ("reporter_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "team_reports_reported_team_id_fkey" FOREIGN KEY ("reported_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "team_reports_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "team_reports_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX "team_reports_reported_team_id_created_at_idx" ON "team_reports"("reported_team_id", "created_at");
CREATE INDEX "team_reports_reporter_team_id_created_at_idx" ON "team_reports"("reporter_team_id", "created_at");
CREATE TABLE "team_blocks" (
  "blocker_team_id" UUID NOT NULL,
  "blocked_team_id" UUID NOT NULL,
  "created_by" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "team_blocks_pkey" PRIMARY KEY ("blocker_team_id", "blocked_team_id"),
  CONSTRAINT "team_blocks_blocker_team_id_fkey" FOREIGN KEY ("blocker_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "team_blocks_blocked_team_id_fkey" FOREIGN KEY ("blocked_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "team_blocks_blocked_team_id_idx" ON "team_blocks"("blocked_team_id");
