import {
  Controller,
  Get,
  HttpStatus,
  Injectable,
  Param,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { AppError } from '../common/errors.js';
import { teamBriefSelect } from '../posts/post-mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { TeamProfileDto } from './matches.dto.js';
import { recentMatches, reviewSummaries, teamRecords } from './team-record.js';

@Injectable()
export class TeamProfileService {
  constructor(private readonly prisma: PrismaService) {}

  /** Hồ sơ công khai của một đội: thành tích, uy tín, nhận xét, trận gần đây. */
  async get(teamId: string): Promise<TeamProfileDto> {
    const team = await this.prisma.team.findUnique({
      where: { id: teamId },
      select: { ...teamBriefSelect, createdAt: true },
    });
    if (!team) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'team_not_found',
        'Không tìm thấy đội',
      );
    }
    const [members, records, summaries, tagRows, reviews, recent] =
      await Promise.all([
        this.prisma.teamMember.count({ where: { teamId, status: 'active' } }),
        teamRecords(this.prisma, [teamId]),
        reviewSummaries(this.prisma, [teamId]),
        this.prisma.teamReview.findMany({
          where: { toTeamId: teamId },
          select: { tags: true },
        }),
        this.prisma.teamReview.findMany({
          where: { toTeamId: teamId, comment: { not: null } },
          include: { fromTeam: { select: teamBriefSelect } },
          orderBy: { createdAt: 'desc' },
          take: 5,
        }),
        recentMatches(this.prisma, teamId),
      ]);
    const opponents = await this.prisma.team.findMany({
      where: { id: { in: recent.map((r) => r.opponentId) } },
      select: teamBriefSelect,
    });
    const oppById = new Map(opponents.map((o) => [o.id, o]));

    const tagCount = new Map<string, number>();
    for (const r of tagRows) {
      for (const t of r.tags) tagCount.set(t, (tagCount.get(t) ?? 0) + 1);
    }
    const sum = summaries.get(teamId)!;
    const rec = records.get(teamId)!;
    const { createdAt, ...brief } = team;
    return {
      team: brief,
      memberCount: members,
      sinceYear: createdAt.getUTCFullYear(),
      record: rec,
      reviewCount: sum.count,
      reputation: sum.reputation,
      fairplay: sum.fairplay,
      onTimePercent: sum.onTimePercent,
      tags: [...tagCount]
        .map(([tag, count]) => ({ tag, count }))
        .sort((a, b) => b.count - a.count || a.tag.localeCompare(b.tag))
        .slice(0, 6),
      reviews: reviews.map((r) => ({
        fromTeam: r.fromTeam,
        reputation: r.reputation,
        fairplay: r.fairplay,
        comment: r.comment,
        createdAt: r.createdAt,
      })),
      recentMatches: recent
        .filter((r) => oppById.has(r.opponentId))
        .map((r) => ({
          matchId: r.matchId,
          opponent: oppById.get(r.opponentId)!,
          startAt: r.startAt,
          goalsFor: r.goalsFor,
          goalsAgainst: r.goalsAgainst,
          outcome: r.outcome,
        })),
    };
  }
}

/** Hồ sơ đội khác: mọi người đã đăng nhập đều xem được. */
@ApiTags('matches')
@ApiBearerAuth()
@Controller('team-profiles')
export class TeamProfileController {
  constructor(private readonly profiles: TeamProfileService) {}

  @Get(':teamId')
  @ApiOkResponse({ type: TeamProfileDto })
  get(@Param('teamId', ParseUUIDPipe) teamId: string): Promise<TeamProfileDto> {
    return this.profiles.get(teamId);
  }
}
