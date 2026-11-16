-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('held', 'confirmed', 'cancelled');

-- AlterTable
ALTER TABLE "events" ADD COLUMN     "booking_id" UUID;

-- AlterTable
ALTER TABLE "posts" ADD COLUMN     "booking_id" UUID,
ADD COLUMN     "pitch_id" UUID;

-- CreateTable
CREATE TABLE "pitches" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "district" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "location" geography(Point,4326) NOT NULL,
    "courts_count" SMALLINT NOT NULL,
    "slot_minutes" SMALLINT NOT NULL DEFAULT 90,
    "slots" JSONB NOT NULL,
    "amenities" TEXT[],
    "phone" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pitches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" TEXT NOT NULL,
    "pitch_id" UUID NOT NULL,
    "team_id" UUID NOT NULL,
    "created_by" UUID NOT NULL,
    "court_no" SMALLINT NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL,
    "end_at" TIMESTAMPTZ(6) NOT NULL,
    "status" "BookingStatus" NOT NULL DEFAULT 'held',
    "price" BIGINT NOT NULL,
    "deposit" BIGINT NOT NULL DEFAULT 0,
    "note" TEXT,
    "held_until" TIMESTAMPTZ(6),
    "slot_key" TEXT,
    "confirmed_at" TIMESTAMPTZ(6),
    "cancelled_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "pitches_slug_key" ON "pitches"("slug");

-- CreateIndex
CREATE INDEX "pitches_location_idx" ON "pitches" USING GIST ("location");

-- CreateIndex
CREATE INDEX "pitches_district_idx" ON "pitches"("district");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_code_key" ON "bookings"("code");

-- CreateIndex
CREATE UNIQUE INDEX "bookings_slot_key_key" ON "bookings"("slot_key");

-- CreateIndex
CREATE INDEX "bookings_team_id_start_at_idx" ON "bookings"("team_id", "start_at");

-- CreateIndex
CREATE INDEX "bookings_pitch_id_start_at_idx" ON "bookings"("pitch_id", "start_at");

-- CreateIndex
CREATE INDEX "bookings_created_by_idx" ON "bookings"("created_by");

-- CreateIndex
CREATE INDEX "bookings_status_held_until_idx" ON "bookings"("status", "held_until");

-- CreateIndex
CREATE UNIQUE INDEX "events_booking_id_key" ON "events"("booking_id");

-- CreateIndex
CREATE UNIQUE INDEX "posts_booking_id_key" ON "posts"("booking_id");

-- CreateIndex
CREATE INDEX "posts_pitch_id_idx" ON "posts"("pitch_id");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "posts" ADD CONSTRAINT "posts_pitch_id_fkey" FOREIGN KEY ("pitch_id") REFERENCES "pitches"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "posts" ADD CONSTRAINT "posts_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_pitch_id_fkey" FOREIGN KEY ("pitch_id") REFERENCES "pitches"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

