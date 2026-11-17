ALTER TABLE "media_uploads" ADD COLUMN "team_id" UUID;

ALTER TABLE "media_uploads"
  ADD CONSTRAINT "media_uploads_team_id_fkey"
  FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;
