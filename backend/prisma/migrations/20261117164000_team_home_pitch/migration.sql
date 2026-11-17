ALTER TABLE "teams" ADD COLUMN "home_pitch_id" UUID;

CREATE INDEX "teams_home_pitch_id_idx" ON "teams"("home_pitch_id");

ALTER TABLE "teams"
ADD CONSTRAINT "teams_home_pitch_id_fkey"
FOREIGN KEY ("home_pitch_id") REFERENCES "pitches"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
