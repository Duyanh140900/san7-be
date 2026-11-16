import { Controller, Get, HttpStatus, Injectable, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AppError } from '../common/errors.js';
import { vnMonth } from '../funds/funds.service.js';
import { teamBriefSelect } from '../posts/post-mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { monthRange, unbeatenStreak } from './match-rules.js';
import {
  HonorPlayerDto,
  HonorsDto,
  HonorsQuery,
  TeamBadgeDto,
} from './matches.dto.js';
import { reviewSummaries, teamRecords } from './team-record.js';

const TOP_SCORERS = 10;
const MIN_UNBEATEN = 5;
const MIN_FAIRPLAY_REVIEWS = 5;
const FAIRPLAY_SCORE = 4.5;

@Injectable()
export class HonorsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Bảng vàng của một tháng: cầu thủ của tháng, vua phá lưới (mọi đội), danh hiệu đội. */
  async get(q: HonorsQuery): Promise<HonorsDto> {
    const month = q.month ?? vnMonth(new Date()).period;
    const range = monthRange(month);
    if (!range) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'invalid_month',
        'Tháng không hợp lệ',
      );
    }
    const where = {
      match: {
        confirmedAt: { not: null },
        startAt: { gte: range.from, lt: range.to },
      },
    } as const;
    const [sums, mvps] = await Promise.all([
      this.prisma.matchPlayerStat.groupBy({
        by: ['userId', 'teamId'],
        where,
        _sum: { goals: true, assists: true },
      }),
      this.prisma.matchPlayerStat.groupBy({
        by: ['userId', 'teamId'],
        where: { ...where, mvp: true },
        _count: { _all: true },
      }),
    ]);
    const mvpBy = new Map(
      mvps.map((r) => [`${r.userId}|${r.teamId}`, r._count._all]),
    );
    const rows = sums.map((r) => ({
      userId: r.userId,
      teamId: r.teamId,
      goals: r._sum.goals ?? 0,
      assists: r._sum.assists ?? 0,
      mvps: mvpBy.get(`${r.userId}|${r.teamId}`) ?? 0,
    }));

    const byScore = [...rows]
      .filter((r) => r.goals > 0)
      .sort(
        (a, b) => b.goals - a.goals || b.assists - a.assists || b.mvps - a.mvps,
      )
      .slice(0, TOP_SCORERS);
    const best = [...rows].sort(
      (a, b) => b.mvps - a.mvps || b.goals - a.goals || b.assists - a.assists,
    )[0];
    const shown = [...byScore, ...(best ? [best] : [])];

    const [users, teams] = await Promise.all([
      this.prisma.user.findMany({
        where: { id: { in: [...new Set(shown.map((r) => r.userId))] } },
        select: { id: true, name: true, avatarUrl: true, position: true },
      }),
      this.prisma.team.findMany({
        where: { id: { in: [...new Set(shown.map((r) => r.teamId))] } },
        select: teamBriefSelect,
      }),
    ]);
    const userBy = new Map(users.map((u) => [u.id, u]));
    const teamBy = new Map(teams.map((t) => [t.id, t]));
    const toPlayer = (r: (typeof rows)[number]): HonorPlayerDto | null => {
      const u = userBy.get(r.userId);
      const t = teamBy.get(r.teamId);
      if (!u || !t) return null;
      return {
        userId: u.id,
        name: u.name,
        avatarUrl: u.avatarUrl,
        position: u.position,
        team: t,
        goals: r.goals,
        assists: r.assists,
        mvps: r.mvps,
      };
    };

    return {
      month,
      playerOfMonth: best ? (toPlayer(best) ?? undefined) : undefined,
      scorers: byScore
        .map(toPlayer)
        .filter((p): p is HonorPlayerDto => p !== null),
      teamBadges: q.teamId ? await this.badges(q.teamId) : [],
    };
  }

  /** Danh hiệu tính từ thành tích và đánh giá của đội. */
  private async badges(teamId: string): Promise<TeamBadgeDto[]> {
    const [records, reviews] = await Promise.all([
      teamRecords(this.prisma, [teamId]),
      reviewSummaries(this.prisma, [teamId]),
    ]);
    const out: TeamBadgeDto[] = [];
    const streak = unbeatenStreak(
      (records.get(teamId)?.form ?? []) as ('W' | 'D' | 'L')[],
    );
    if (streak >= MIN_UNBEATEN) out.push({ type: 'unbeaten', value: streak });
    const r = reviews.get(teamId);
    if (
      r &&
      r.count >= MIN_FAIRPLAY_REVIEWS &&
      r.fairplay !== null &&
      r.fairplay >= FAIRPLAY_SCORE
    ) {
      out.push({ type: 'fairplay', value: r.fairplay });
    }
    return out;
  }
}

/** Bảng vàng toàn hệ thống: mọi người đã đăng nhập đều xem được. */
@ApiTags('matches')
@ApiBearerAuth()
@Controller('honors')
export class HonorsController {
  constructor(private readonly honors: HonorsService) {}

  @Get()
  @ApiOkResponse({ type: HonorsDto })
  get(@Query() q: HonorsQuery): Promise<HonorsDto> {
    return this.honors.get(q);
  }
}
