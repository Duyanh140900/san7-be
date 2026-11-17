CREATE TYPE "MediaUploadStatus" AS ENUM ('pending', 'processing', 'ready', 'rejected', 'expired');

CREATE TABLE "media_uploads" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "owner_id" UUID NOT NULL,
    "purpose" TEXT NOT NULL,
    "expected_size" INTEGER NOT NULL,
    "quarantine_key" TEXT NOT NULL,
    "public_key" TEXT NOT NULL,
    "status" "MediaUploadStatus" NOT NULL DEFAULT 'pending',
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "finalized_at" TIMESTAMPTZ(6),
    "referenced_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "media_uploads_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "media_uploads_quarantine_key_key" ON "media_uploads"("quarantine_key");
CREATE UNIQUE INDEX "media_uploads_public_key_key" ON "media_uploads"("public_key");
CREATE INDEX "media_uploads_owner_id_created_at_idx" ON "media_uploads"("owner_id", "created_at");
CREATE INDEX "media_uploads_status_expires_at_idx" ON "media_uploads"("status", "expires_at");

ALTER TABLE "media_uploads"
  ADD CONSTRAINT "media_uploads_owner_id_fkey"
  FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
