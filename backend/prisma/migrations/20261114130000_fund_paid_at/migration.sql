-- AlterTable
ALTER TABLE "fund_transactions" ADD COLUMN     "paid_at" TIMESTAMPTZ(6);

-- CreateIndex
CREATE INDEX "fund_transactions_team_id_paid_at_idx" ON "fund_transactions"("team_id", "paid_at");


-- Dữ liệu cũ: khoản đã nộp lấy thời điểm tạo làm thời điểm nộp
UPDATE "fund_transactions" SET "paid_at" = "created_at" WHERE "paid" = true AND "paid_at" IS NULL;
