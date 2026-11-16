-- AlterTable
ALTER TABLE "fund_transactions" ADD COLUMN     "auto_key" TEXT;

-- AlterTable
ALTER TABLE "matches" ADD COLUMN     "away_score" SMALLINT,
ADD COLUMN     "confirmed_at" TIMESTAMPTZ(6),
ADD COLUMN     "home_score" SMALLINT,
ADD COLUMN     "pitch_price" BIGINT,
ADD COLUMN     "ratio_lose" SMALLINT,
ADD COLUMN     "ratio_win" SMALLINT,
ADD COLUMN     "reported_at" TIMESTAMPTZ(6),
ADD COLUMN     "reported_by_team_id" UUID;

-- CreateTable
CREATE TABLE "match_player_stats" (
    "match_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "goals" SMALLINT NOT NULL DEFAULT 0,
    "assists" SMALLINT NOT NULL DEFAULT 0,
    "mvp" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "match_player_stats_pkey" PRIMARY KEY ("match_id","user_id")
);

-- CreateTable
CREATE TABLE "team_reviews" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "match_id" UUID NOT NULL,
    "from_team_id" UUID NOT NULL,
    "to_team_id" UUID NOT NULL,
    "created_by" UUID NOT NULL,
    "reputation" SMALLINT NOT NULL,
    "fairplay" SMALLINT NOT NULL,
    "tags" TEXT[],
    "comment" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "team_reviews_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "match_player_stats_user_id_idx" ON "match_player_stats"("user_id");

-- CreateIndex
CREATE INDEX "match_player_stats_team_id_idx" ON "match_player_stats"("team_id");

-- CreateIndex
CREATE INDEX "team_reviews_to_team_id_created_at_idx" ON "team_reviews"("to_team_id", "created_at");

-- CreateIndex
CREATE INDEX "team_reviews_created_by_idx" ON "team_reviews"("created_by");

-- CreateIndex
CREATE UNIQUE INDEX "team_reviews_match_id_from_team_id_key" ON "team_reviews"("match_id", "from_team_id");

-- CreateIndex
CREATE UNIQUE INDEX "fund_transactions_auto_key_key" ON "fund_transactions"("auto_key");

-- AddForeignKey
ALTER TABLE "match_player_stats" ADD CONSTRAINT "match_player_stats_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_player_stats" ADD CONSTRAINT "match_player_stats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "match_player_stats" ADD CONSTRAINT "match_player_stats_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_reviews" ADD CONSTRAINT "team_reviews_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_reviews" ADD CONSTRAINT "team_reviews_from_team_id_fkey" FOREIGN KEY ("from_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_reviews" ADD CONSTRAINT "team_reviews_to_team_id_fkey" FOREIGN KEY ("to_team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "team_reviews" ADD CONSTRAINT "team_reviews_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

