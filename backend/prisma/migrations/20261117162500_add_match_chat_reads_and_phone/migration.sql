ALTER TABLE "users" ADD COLUMN "phone" TEXT;

CREATE TABLE "match_chat_reads" (
  "match_id" UUID NOT NULL,
  "team_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "last_read_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "match_chat_reads_pkey" PRIMARY KEY ("match_id", "team_id"),
  CONSTRAINT "match_chat_reads_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "match_chat_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "match_chat_reads_user_id_idx" ON "match_chat_reads"("user_id");
