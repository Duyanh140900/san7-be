ALTER TYPE "BookingStatus" ADD VALUE IF NOT EXISTS 'deposit_claimed';

ALTER TABLE "pitches"
  ADD COLUMN "bank_bin" TEXT,
  ADD COLUMN "account_no" TEXT,
  ADD COLUMN "account_name" TEXT;

ALTER TABLE "bookings"
  ADD COLUMN "transfer_code" TEXT,
  ADD COLUMN "services" JSONB NOT NULL DEFAULT '[]',
  ADD COLUMN "extra_amount" BIGINT NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX "bookings_transfer_code_key" ON "bookings"("transfer_code");

CREATE TABLE "pitch_reviews" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "pitch_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "booking_id" UUID,
  "stars" SMALLINT NOT NULL,
  "turf" SMALLINT NOT NULL,
  "lighting" SMALLINT NOT NULL,
  "locker_room" SMALLINT NOT NULL,
  "owner_price" SMALLINT NOT NULL,
  "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "comment" TEXT,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "pitch_reviews_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "pitch_reviews_pitch_id_user_id_booking_id_key" ON "pitch_reviews"("pitch_id", "user_id", "booking_id");
CREATE INDEX "pitch_reviews_pitch_id_created_at_idx" ON "pitch_reviews"("pitch_id", "created_at");
CREATE INDEX "pitch_reviews_user_id_idx" ON "pitch_reviews"("user_id");
ALTER TABLE "pitch_reviews" ADD CONSTRAINT "pitch_reviews_pitch_id_fkey" FOREIGN KEY ("pitch_id") REFERENCES "pitches"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "pitch_reviews" ADD CONSTRAINT "pitch_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "pitch_reviews" ADD CONSTRAINT "pitch_reviews_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;
