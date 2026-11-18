CREATE TABLE "team_follows" (
  "user_id" UUID NOT NULL,
  "team_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "team_follows_pkey" PRIMARY KEY ("user_id", "team_id"),
  CONSTRAINT "team_follows_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "team_follows_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "team_follows_team_id_created_at_idx" ON "team_follows"("team_id", "created_at");
