import { vnShort } from '../common/vn-time.js';
import type { Prisma } from '../generated/prisma/client.js';
import {
  notifyTeamManagers,
  type NotificationRow,
} from '../notifications/notification-writer.js';

/**
 * Sau giờ kết thúc trận: nhắc đội trưởng/phó hai đội nhập tỉ số và đánh giá đối thủ.
 * Bỏ qua nếu trận đã huỷ, đã có người nhập tỉ số hoặc chưa tới giờ. Gọi từ worker.
 */
export async function promptMatchResult(
  prisma: {
    $transaction: <T>(
      fn: (tx: Prisma.TransactionClient) => Promise<T>,
    ) => Promise<T>;
  },
  matchId: string,
  now: Date,
): Promise<NotificationRow[]> {
  return prisma.$transaction(async (tx) => {
    const m = await tx.match.findUnique({
      where: { id: matchId },
      include: {
        homeTeam: { select: { id: true, name: true } },
        awayTeam: { select: { id: true, name: true } },
      },
    });
    if (
      !m ||
      m.status !== 'scheduled' ||
      m.homeScore !== null ||
      m.endAt > now
    ) {
      return [];
    }
    const rows: NotificationRow[] = [];
    for (const [me, opp] of [
      [m.homeTeam, m.awayTeam],
      [m.awayTeam, m.homeTeam],
    ] as const) {
      rows.push(
        ...(await notifyTeamManagers(
          tx,
          [{ teamId: me.id, payload: { matchId: m.id, teamId: me.id } }],
          {
            type: 'match.prompt_result',
            category: 'match',
            title: `Trận gặp ${opp.name} đã kết thúc`,
            body: `${vnShort(m.startAt)} · Nhập tỉ số và đánh giá đối thủ`,
          },
        )),
      );
    }
    return rows;
  });
}
