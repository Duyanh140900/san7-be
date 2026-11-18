-- Payment confirmations for team funds, score re-proposals, and MVP voting.
CREATE TYPE "FundPaymentStatus" AS ENUM ('approved', 'pending', 'rejected');

ALTER TABLE "teams"
  ADD COLUMN "treasurer_bank_bin" TEXT,
  ADD COLUMN "treasurer_account_no" TEXT,
  ADD COLUMN "treasurer_account_name" TEXT;

ALTER TABLE "fund_transactions"
  ADD COLUMN "payment_status" "FundPaymentStatus" NOT NULL DEFAULT 'approved',
  ADD COLUMN "transfer_code" TEXT;

CREATE UNIQUE INDEX "fund_transactions_transfer_code_key"
  ON "fund_transactions"("transfer_code");
CREATE INDEX "fund_transactions_team_id_payment_status_created_at_idx"
  ON "fund_transactions"("team_id", "payment_status", "created_at");

ALTER TABLE "matches"
  ADD COLUMN "result_auto_confirm_at" TIMESTAMPTZ(6);
CREATE INDEX "matches_result_auto_confirm_at_idx"
  ON "matches"("result_auto_confirm_at");

CREATE TABLE "mvp_votes" (
  "match_id" UUID NOT NULL,
  "voter_id" UUID NOT NULL,
  "candidate_user_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "mvp_votes_pkey" PRIMARY KEY ("match_id", "voter_id"),
  CONSTRAINT "mvp_votes_match_id_fkey" FOREIGN KEY ("match_id") REFERENCES "matches"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "mvp_votes_voter_id_fkey" FOREIGN KEY ("voter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "mvp_votes_candidate_user_id_fkey" FOREIGN KEY ("candidate_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "mvp_votes_match_id_candidate_user_id_idx"
  ON "mvp_votes"("match_id", "candidate_user_id");
