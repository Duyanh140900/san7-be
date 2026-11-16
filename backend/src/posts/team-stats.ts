import type { Prisma } from '../generated/prisma/client.js';
import {
  confirmedMatches,
  reviewSummaries,
  teamRecords,
} from '../matches/team-record.js';

export interface TeamStats {
  memberCount: number;
  /** số trận đã có kết quả được hai đội xác nhận */
  matchesPlayed: number;
  /** số lần đã gặp đội đăng kèo (trận đã xác nhận) */
  headToHead: number;
  /** trong các lần gặp đó: đội đăng kèo thắng / thua */
  h2hOwnerWins: number;
  h2hOwnerLosses: number;
  reputation: number | null;
  reviewCount: number;
  onTimePercent: number | null;
}

type Db = Pick<Prisma.TransactionClient, 'teamMember' | 'match' | 'teamReview'>;

/**
 * Số liệu cho màn so sánh đội nhận kèo: thành viên, số trận, đối đầu với đội đăng kèo,
 * uy tín và tỉ lệ đúng giờ (từ đánh giá sau trận).
 */
export async function teamStats(
  db: Db,
  ownerTeamId: string,
  teamIds: string[],
): Promise<Map<string, TeamStats>> {
  const stats = new Map<string, TeamStats>(
    teamIds.map((id) => [
      id,
      {
        memberCount: 0,
        matchesPlayed: 0,
        headToHead: 0,
        h2hOwnerWins: 0,
        h2hOwnerLosses: 0,
        reputation: null,
        reviewCount: 0,
        onTimePercent: null,
      },
    ]),
  );
  if (teamIds.length === 0) return stats;

  const [members, records, reviews, ownerMatches] = await Promise.all([
    db.teamMember.groupBy({
      by: ['teamId'],
      where: { teamId: { in: teamIds }, status: 'active' },
      _count: { _all: true },
    }),
    teamRecords(db, teamIds),
    reviewSummaries(db, teamIds),
    confirmedMatches(db, [ownerTeamId]),
  ]);
  for (const m of members) stats.get(m.teamId)!.memberCount = m._count._all;
  for (const [id, s] of stats) {
    s.matchesPlayed = records.get(id)?.played ?? 0;
    const r = reviews.get(id);
    s.reviewCount = r?.count ?? 0;
    s.reputation = r?.reputation ?? null;
    s.onTimePercent = r?.onTimePercent ?? null;
  }
  for (const m of ownerMatches) {
    const ownerHome = m.homeTeamId === ownerTeamId;
    const other = ownerHome ? m.awayTeamId : m.homeTeamId;
    const s = stats.get(other);
    if (!s) continue;
    const ownerGoals = ownerHome ? m.homeScore! : m.awayScore!;
    const otherGoals = ownerHome ? m.awayScore! : m.homeScore!;
    s.headToHead++;
    if (ownerGoals > otherGoals) s.h2hOwnerWins++;
    else if (ownerGoals < otherGoals) s.h2hOwnerLosses++;
  }
  return stats;
}
