import type { Prisma } from '../generated/prisma/client.js';
import { outcomeOf, type Outcome } from './match-rules.js';

export interface TeamRecord {
  played: number;
  wins: number;
  draws: number;
  losses: number;
  goalsFor: number;
  goalsAgainst: number;
  /** tối đa 5 trận gần nhất, mới nhất đứng đầu */
  form: Outcome[];
}

export interface RecentMatch {
  matchId: string;
  opponentId: string;
  startAt: Date;
  goalsFor: number;
  goalsAgainst: number;
  outcome: Outcome;
}

const empty = (): TeamRecord => ({
  played: 0,
  wins: 0,
  draws: 0,
  losses: 0,
  goalsFor: 0,
  goalsAgainst: 0,
  form: [],
});

/** Các trận đã được hai đội xác nhận tỉ số, mới nhất trước. */
export async function confirmedMatches(
  db: Pick<Prisma.TransactionClient, 'match'>,
  teamIds: string[],
  extra: Prisma.MatchWhereInput = {},
) {
  return db.match.findMany({
    where: {
      confirmedAt: { not: null },
      homeScore: { not: null },
      awayScore: { not: null },
      OR: [{ homeTeamId: { in: teamIds } }, { awayTeamId: { in: teamIds } }],
      ...extra,
    },
    select: {
      id: true,
      homeTeamId: true,
      awayTeamId: true,
      homeScore: true,
      awayScore: true,
      startAt: true,
    },
    orderBy: { startAt: 'desc' },
  });
}

/** Thành tích từng đội (chỉ tính trận đã xác nhận). */
export async function teamRecords(
  db: Pick<Prisma.TransactionClient, 'match'>,
  teamIds: string[],
): Promise<Map<string, TeamRecord>> {
  const out = new Map<string, TeamRecord>(teamIds.map((id) => [id, empty()]));
  if (teamIds.length === 0) return out;
  for (const m of await confirmedMatches(db, teamIds)) {
    const sides = [
      { id: m.homeTeamId, gf: m.homeScore!, ga: m.awayScore! },
      { id: m.awayTeamId, gf: m.awayScore!, ga: m.homeScore! },
    ];
    for (const s of sides) {
      const r = out.get(s.id);
      if (!r) continue;
      const o = outcomeOf(s.gf, s.ga);
      r.played++;
      r.goalsFor += s.gf;
      r.goalsAgainst += s.ga;
      if (o === 'W') r.wins++;
      else if (o === 'D') r.draws++;
      else r.losses++;
      if (r.form.length < 5) r.form.push(o);
    }
  }
  return out;
}

/** Các trận gần nhất của một đội (đã xác nhận). */
export async function recentMatches(
  db: Pick<Prisma.TransactionClient, 'match'>,
  teamId: string,
  take = 5,
): Promise<RecentMatch[]> {
  const rows = await confirmedMatches(db, [teamId]);
  return rows.slice(0, take).map((m) => {
    const home = m.homeTeamId === teamId;
    const gf = home ? m.homeScore! : m.awayScore!;
    const ga = home ? m.awayScore! : m.homeScore!;
    return {
      matchId: m.id,
      opponentId: home ? m.awayTeamId : m.homeTeamId,
      startAt: m.startAt,
      goalsFor: gf,
      goalsAgainst: ga,
      outcome: outcomeOf(gf, ga),
    };
  });
}

export interface ReviewSummary {
  count: number;
  /** trung bình uy tín 1–5, một chữ số thập phân; null khi chưa có đánh giá */
  reputation: number | null;
  fairplay: number | null;
  /** % đánh giá có nhãn "Đúng giờ"; null khi chưa có đánh giá */
  onTimePercent: number | null;
}

const round1 = (n: number) => Math.round(n * 10) / 10;

/** Tổng hợp đánh giá nhận được của từng đội. */
export async function reviewSummaries(
  db: Pick<Prisma.TransactionClient, 'teamReview'>,
  teamIds: string[],
): Promise<Map<string, ReviewSummary>> {
  const out = new Map<string, ReviewSummary>(
    teamIds.map((id) => [
      id,
      { count: 0, reputation: null, fairplay: null, onTimePercent: null },
    ]),
  );
  if (teamIds.length === 0) return out;
  const [avg, onTime] = await Promise.all([
    db.teamReview.groupBy({
      by: ['toTeamId'],
      where: { toTeamId: { in: teamIds } },
      _count: { _all: true },
      _avg: { reputation: true, fairplay: true },
    }),
    db.teamReview.groupBy({
      by: ['toTeamId'],
      where: { toTeamId: { in: teamIds }, tags: { has: 'on_time' } },
      _count: { _all: true },
    }),
  ]);
  const onTimeBy = new Map(onTime.map((r) => [r.toTeamId, r._count._all]));
  for (const r of avg) {
    const count = r._count._all;
    out.set(r.toTeamId, {
      count,
      reputation: r._avg.reputation === null ? null : round1(r._avg.reputation),
      fairplay: r._avg.fairplay === null ? null : round1(r._avg.fairplay),
      onTimePercent: Math.round(
        ((onTimeBy.get(r.toTeamId) ?? 0) / count) * 100,
      ),
    });
  }
  return out;
}
