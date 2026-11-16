import type { Prisma } from '../generated/prisma/client.js';
import { slotMapKey } from './pitch-slots.js';

/**
 * Số sân đã bị chiếm theo (sân, giờ bắt đầu): đã xác nhận, hoặc đang giữ chỗ chưa hết hạn.
 * Khoá map dạng slotMapKey(pitchId, startAt).
 */
export async function countTaken(
  db: Pick<Prisma.TransactionClient, 'booking'>,
  pitchIds: string[],
  from: Date,
  to: Date,
  now: Date,
): Promise<Map<string, number>> {
  const out = new Map<string, number>();
  if (pitchIds.length === 0) return out;
  const rows = await db.booking.groupBy({
    by: ['pitchId', 'startAt'],
    where: {
      pitchId: { in: pitchIds },
      startAt: { gte: from, lte: to },
      OR: [{ status: 'confirmed' }, { status: 'held', heldUntil: { gt: now } }],
    },
    _count: { _all: true },
  });
  for (const r of rows)
    out.set(slotMapKey(r.pitchId, r.startAt), r._count._all);
  return out;
}
