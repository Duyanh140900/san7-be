ALTER TABLE "fund_transactions" ADD COLUMN "receipt_key" TEXT;

CREATE INDEX "fund_transactions_receipt_key_idx"
  ON "fund_transactions"("receipt_key");
