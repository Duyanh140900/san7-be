import type { Prisma } from '../generated/prisma/client.js';

export interface TeamStats {
  memberCount: number;
  matchesPlayed: number;
  headToHead: number;
}

type Db = Pick<Prisma.TransactionClient, 'teamMember' | 'match'>;

/**
 * Số liệu cho màn so sánh đội nhận kèo: số thành viên, số trận đã đá,
 * số lần đã gặp đội đăng kèo. Uy tín, đúng giờ thêm ở M4 (cần kết quả trận).
 */
export async function teamStats(
  db: Db,
  ownerTeamId: string,
  teamIds: string[],
  now: Date,
): Promise<Map<string, TeamStats>> {
  const stats = new Map<string, TeamStats>(
    teamIds.map((id) => [
      id,
      { memberCount: 0, matchesPlayed: 0, headToHead: 0 },
    ]),
  );
  if (teamIds.length === 0) return stats;

  const played = {
    startAt: { lt: now },
    status: { not: 'cancelled' },
  } as const;
  const [members, home, away, h2h] = await Promise.all([
    db.teamMember.groupBy({
      by: ['teamId'],
      where: { teamId: { in: teamIds }, status: 'active' },
      _count: { _all: true },
    }),
    db.match.groupBy({
      by: ['homeTeamId'],
      where: { homeTeamId: { in: teamIds }, ...played },
      _count: { _all: true },
    }),
    db.match.groupBy({
      by: ['awayTeamId'],
      where: { awayTeamId: { in: teamIds }, ...played },
      _count: { _all: true },
    }),
    db.match.findMany({
      where: {
        ...played,
        OR: [
          { homeTeamId: ownerTeamId, awayTeamId: { in: teamIds } },
          { awayTeamId: ownerTeamId, homeTeamId: { in: teamIds } },
        ],
      },
      select: { homeTeamId: true, awayTeamId: true },
    }),
  ]);
  for (const m of members) stats.get(m.teamId)!.memberCount = m._count._all;
  for (const m of home) stats.get(m.homeTeamId)!.matchesPlayed += m._count._all;
  for (const m of away) stats.get(m.awayTeamId)!.matchesPlayed += m._count._all;
  for (const m of h2h) {
    const other = m.homeTeamId === ownerTeamId ? m.awayTeamId : m.homeTeamId;
    stats.get(other)!.headToHead++;
  }
  return stats;
}
