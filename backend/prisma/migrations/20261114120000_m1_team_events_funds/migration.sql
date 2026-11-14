-- CreateEnum
CREATE TYPE "EventKind" AS ENUM ('match', 'internal', 'other');

-- CreateEnum
CREATE TYPE "AttendanceStatus" AS ENUM ('go', 'maybe', 'no');

-- CreateEnum
CREATE TYPE "FundType" AS ENUM ('income', 'expense', 'fine');

-- AlterTable
ALTER TABLE "teams" ADD COLUMN     "fund_balance" BIGINT NOT NULL DEFAULT 0,
ADD COLUMN     "monthly_due" BIGINT NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "team_id" UUID NOT NULL,
    "kind" "EventKind" NOT NULL,
    "title" TEXT NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL,
    "end_at" TIMESTAMPTZ(6) NOT NULL,
    "location" TEXT,
    "note" TEXT,
    "min_players" SMALLINT,
    "created_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attendances" (
    "event_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "AttendanceStatus" NOT NULL,
    "note" TEXT,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "attendances_pkey" PRIMARY KEY ("event_id","user_id")
);

-- CreateTable
CREATE TABLE "fund_transactions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "team_id" UUID NOT NULL,
    "type" "FundType" NOT NULL,
    "amount" BIGINT NOT NULL,
    "category" TEXT NOT NULL,
    "member_id" UUID,
    "event_id" UUID,
    "period" TEXT,
    "batch_id" UUID,
    "note" TEXT,
    "paid" BOOLEAN NOT NULL DEFAULT true,
    "created_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fund_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fine_rules" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "team_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "amount" BIGINT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fine_rules_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "events_team_id_start_at_idx" ON "events"("team_id", "start_at");

-- CreateIndex
CREATE INDEX "events_created_by_idx" ON "events"("created_by");

-- CreateIndex
CREATE INDEX "attendances_user_id_idx" ON "attendances"("user_id");

-- CreateIndex
CREATE INDEX "fund_transactions_team_id_created_at_idx" ON "fund_transactions"("team_id", "created_at");

-- CreateIndex
CREATE INDEX "fund_transactions_team_id_period_idx" ON "fund_transactions"("team_id", "period");

-- CreateIndex
CREATE INDEX "fund_transactions_member_id_idx" ON "fund_transactions"("member_id");

-- CreateIndex
CREATE INDEX "fund_transactions_event_id_idx" ON "fund_transactions"("event_id");

-- CreateIndex
CREATE INDEX "fund_transactions_created_by_idx" ON "fund_transactions"("created_by");

-- CreateIndex
CREATE INDEX "fine_rules_team_id_idx" ON "fine_rules"("team_id");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attendances" ADD CONSTRAINT "attendances_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fund_transactions" ADD CONSTRAINT "fund_transactions_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fund_transactions" ADD CONSTRAINT "fund_transactions_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fund_transactions" ADD CONSTRAINT "fund_transactions_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "events"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fund_transactions" ADD CONSTRAINT "fund_transactions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fine_rules" ADD CONSTRAINT "fine_rules_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "teams"("id") ON DELETE CASCADE ON UPDATE CASCADE;

