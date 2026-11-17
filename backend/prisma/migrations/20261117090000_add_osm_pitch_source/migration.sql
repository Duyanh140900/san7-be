-- Track provenance for externally imported pitches without changing manual data.
CREATE TYPE "PitchSource" AS ENUM ('manual', 'osm');

ALTER TABLE "pitches"
  ADD COLUMN "osm_id" TEXT,
  ADD COLUMN "source" "PitchSource" NOT NULL DEFAULT 'manual',
  ADD COLUMN "price_estimated" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "opening_hours" TEXT;

CREATE UNIQUE INDEX "pitches_osm_id_key" ON "pitches"("osm_id");
