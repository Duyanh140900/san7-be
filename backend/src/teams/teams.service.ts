import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  generateInviteCode,
  INVITE_CODE_PATTERN,
  normalizeInviteCode,
} from './invite-code.js';
import { toMoney } from '../common/money.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type {
  CreateTeamDto,
  InviteDto,
  MembershipDto,
  TeamDetailDto,
  TeamDto,
  TeamInvitePreviewDto,
  TeamPublicProfileDto,
  UpdateTeamDto,
  TeamMemberDto,
} from './teams.dto.js';
import type { TeamRole } from '../generated/prisma/enums.js';

const INVITE_TTL_DAYS = 7;
const CREST_COLORS = [
  '#0066CC',
  '#248A3D',
  '#C4000F',
  '#FF9500',
  '#272729',
  '#5E5CE6',
];

@Injectable()
export class TeamsService {
  constructor(private readonly prisma: PrismaService) {}

  /** Tạo đội: người tạo thành đội trưởng (active) ngay, trong cùng một transaction. */
  async create(userId: string, dto: CreateTeamDto): Promise<TeamDto> {
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        const team = await this.prisma.$transaction(async (tx) => {
          const created = await tx.team.create({
            data: {
              name: dto.name.trim(),
              area: dto.area.trim(),
              level: dto.level,
              crestColor:
                dto.crestColor?.toUpperCase() ?? pickCrestColor(dto.name),
              inviteCode: generateInviteCode(),
              inviteExpiresAt: new Date(
                Date.now() + INVITE_TTL_DAYS * 86_400_000,
              ),
              createdById: userId,
            },
          });
          await tx.teamMember.create({
            data: {
              teamId: created.id,
              userId,
              role: 'captain',
              status: 'active',
              joinedAt: new Date(),
            },
          });
          return created;
        });
        return toTeamDto(team);
      } catch (e) {
        // Trùng mã mời (rất hiếm): thử mã khác
        if (isUniqueViolation(e, 'invite_code')) continue;
        throw e;
      }
    }
    throw new AppError(
      HttpStatus.CONFLICT,
      'invite_code_exhausted',
      'Không tạo được mã mời, thử lại',
    );
  }

  async detail(me: TeamMembership): Promise<TeamDetailDto> {
    const team = await this.prisma.team.findUniqueOrThrow({
      where: { id: me.teamId },
    });
    const memberCount = await this.prisma.teamMember.count({
      where: { teamId: me.teamId, status: 'active' },
    });
    const canInvite = me.role === 'captain' || me.role === 'vice';
    return {
      id: team.id,
      name: team.name,
      crestColor: team.crestColor,
      area: team.area,
      level: team.level,
      createdAt: team.createdAt,
      memberCount,
      myRole: me.role,
      monthlyDue: toMoney(team.monthlyDue),
      homePitchId: team.homePitchId,
      inviteCode: canInvite ? team.inviteCode : undefined,
      inviteExpiresAt: canInvite ? team.inviteExpiresAt : undefined,
    };
  }

  async update(me: TeamMembership, dto: UpdateTeamDto): Promise<TeamDetailDto> {
    await this.prisma.team.update({
      where: { id: me.teamId },
      data: {
        name: dto.name,
        area: dto.area,
        level: dto.level,
        crestColor: dto.crestColor?.toUpperCase(),
        monthlyDue:
          dto.monthlyDue === undefined ? undefined : BigInt(dto.monthlyDue),
        homePitchId: dto.homePitchId,
      },
    });
    return this.detail(me);
  }

  /** Tạo mã mời mới (mã cũ hết hiệu lực ngay). */
  async regenerateInvite(me: TeamMembership): Promise<InviteDto> {
    for (let attempt = 0; attempt < 5; attempt++) {
      try {
        const team = await this.prisma.team.update({
          where: { id: me.teamId },
          data: {
            inviteCode: generateInviteCode(),
            inviteExpiresAt: new Date(
              Date.now() + INVITE_TTL_DAYS * 86_400_000,
            ),
          },
        });
        return {
          inviteCode: team.inviteCode,
          inviteExpiresAt: team.inviteExpiresAt!,
        };
      } catch (e) {
        if (isUniqueViolation(e, 'invite_code')) continue;
        throw e;
      }
    }
    throw new AppError(
      HttpStatus.CONFLICT,
      'invite_code_exhausted',
      'Không tạo được mã mời, thử lại',
    );
  }

  async previewInvite(code: string): Promise<TeamInvitePreviewDto> {
    const team = await this.findByInvite(code);
    const memberCount = await this.prisma.teamMember.count({
      where: { teamId: team.id, status: 'active' },
    });
    return {
      teamId: team.id,
      name: team.name,
      crestColor: team.crestColor,
      area: team.area,
      level: team.level,
      memberCount,
    };
  }

  /** Vào đội bằng mã mời: tạo yêu cầu chờ đội trưởng duyệt. */
  async join(userId: string, code: string): Promise<MembershipDto> {
    const team = await this.findByInvite(code);
    const existing = await this.prisma.teamMember.findUnique({
      where: { teamId_userId: { teamId: team.id, userId } },
    });
    const pendingError = new AppError(
      HttpStatus.CONFLICT,
      'join_pending',
      'Bạn đã gửi yêu cầu, đang chờ đội trưởng duyệt',
    );
    if (existing) {
      if (existing.status === 'active') {
        throw new AppError(
          HttpStatus.CONFLICT,
          'already_member',
          'Bạn đã ở trong đội này',
        );
      }
      throw pendingError;
    }
    let member;
    try {
      member = await this.prisma.teamMember.create({
        data: { teamId: team.id, userId, role: 'member', status: 'pending' },
      });
    } catch (e) {
      // Bấm hai lần liên tiếp: request sau trùng (team_id, user_id)
      if (isUniqueViolation(e, 'team_id')) throw pendingError;
      throw e;
    }
    return {
      teamId: team.id,
      teamName: team.name,
      role: member.role,
      status: member.status,
    };
  }

  async follow(userId: string, teamId: string): Promise<void> {
    await this.prisma.team.findUniqueOrThrow({ where: { id: teamId }, select: { id: true } });
    await this.prisma.teamFollow.upsert({ where: { userId_teamId: { userId, teamId } }, create: { userId, teamId }, update: {} });
  }

  async unfollow(userId: string, teamId: string): Promise<void> {
    await this.prisma.teamFollow.deleteMany({ where: { userId, teamId } });
  }

  async publicProfile(userId: string, teamId: string): Promise<TeamPublicProfileDto> {
    const [team, reviews, matches, following] = await Promise.all([
      this.prisma.team.findUnique({ where: { id: teamId } }),
      this.prisma.teamReview.findMany({ where: { toTeamId: teamId }, select: { reputation: true, tags: true } }),
      this.prisma.match.findMany({ where: { status: 'finished', OR: [{ homeTeamId: teamId }, { awayTeamId: teamId }] }, select: { homeTeamId: true, homeScore: true, awayScore: true, startAt: true }, orderBy: { startAt: 'desc' }, take: 5 }),
      this.prisma.teamFollow.findUnique({ where: { userId_teamId: { userId, teamId } } }),
    ]);
    if (!team) throw new AppError(HttpStatus.NOT_FOUND, 'team_not_found', 'Không tìm thấy đội');
    const tags: Record<string, number> = {};
    for (const review of reviews) for (const tag of review.tags) tags[tag] = (tags[tag] ?? 0) + 1;
    let wins = 0; let draws = 0; let losses = 0;
    const form = matches.map((match) => { const mine = match.homeTeamId === teamId ? match.homeScore : match.awayScore; const theirs = match.homeTeamId === teamId ? match.awayScore : match.homeScore; if (mine === theirs) { draws++; return 'D'; } if ((mine ?? 0) > (theirs ?? 0)) { wins++; return 'W'; } losses++; return 'L'; });
    return { id: team.id, name: team.name, crestColor: team.crestColor, area: team.area, level: team.level, reputation: reviews.length ? Number((reviews.reduce((sum, item) => sum + item.reputation, 0) / reviews.length).toFixed(1)) : 0, reviewCount: reviews.length, onTimePercent: reviews.length ? Math.round(((tags.on_time ?? 0) / reviews.length) * 100) : 0, keepDealPercent: reviews.length ? Math.round(((tags.fair_pay ?? 0) / reviews.length) * 100) : 0, wins, draws, losses, form, reviewTags: tags, recentMatchCount: matches.length, isFollowing: Boolean(following) };
  }

  async joinRequests(me: TeamMembership): Promise<TeamMemberDto[]> {
    const rows = await this.prisma.teamMember.findMany({
      where: { teamId: me.teamId, status: 'pending' },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(toMemberDto);
  }

  async resolveJoinRequest(me: TeamMembership, userId: string, accept: boolean): Promise<MembershipDto> {
    const member = await this.prisma.teamMember.findUnique({
      where: { teamId_userId: { teamId: me.teamId, userId } }, include: { team: true },
    });
    if (!member || member.status !== 'pending') {
      throw new AppError(HttpStatus.NOT_FOUND, 'join_request_not_found', 'Không tìm thấy yêu cầu vào đội đang chờ duyệt');
    }
    if (!accept) {
      await this.prisma.teamMember.delete({ where: { id: member.id } });
      return { teamId: member.teamId, teamName: member.team.name, role: member.role, status: 'pending' };
    }
    const updated = await this.prisma.teamMember.update({
      where: { id: member.id }, data: { status: 'active', joinedAt: new Date() },
    });
    return { teamId: updated.teamId, teamName: member.team.name, role: updated.role, status: updated.status };
  }

  async updateMemberRole(me: TeamMembership, userId: string, role: TeamRole): Promise<TeamMemberDto> {
    if (role === 'captain') {
      throw new AppError(HttpStatus.UNPROCESSABLE_ENTITY, 'captain_role_locked', 'Không thể đổi đội trưởng bằng API này');
    }
    const member = await this.prisma.teamMember.findUnique({ where: { teamId_userId: { teamId: me.teamId, userId } } });
    if (!member || member.status !== 'active') throw new AppError(HttpStatus.NOT_FOUND, 'team_member_not_found', 'Không tìm thấy thành viên');
    if (member.role === 'captain') throw new AppError(HttpStatus.UNPROCESSABLE_ENTITY, 'captain_role_locked', 'Không thể đổi vai trò đội trưởng');
    const updated = await this.prisma.teamMember.update({
      where: { id: member.id }, data: { role }, include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });
    return toMemberDto(updated);
  }

  private async findByInvite(code: string) {
    const normalized = normalizeInviteCode(code);
    const notFound = new AppError(
      HttpStatus.NOT_FOUND,
      'invite_not_found',
      'Mã mời không đúng',
    );
    if (!INVITE_CODE_PATTERN.test(normalized)) throw notFound;
    const team = await this.prisma.team.findUnique({
      where: { inviteCode: normalized },
    });
    if (!team) throw notFound;
    if (team.inviteExpiresAt && team.inviteExpiresAt.getTime() < Date.now()) {
      throw new AppError(
        HttpStatus.GONE,
        'invite_expired',
        'Mã mời đã hết hạn, xin đội trưởng mã mới',
      );
    }
    return team;
  }
}

function toMemberDto(row: { user: { id: string; name: string; avatarUrl: string | null }; role: TeamRole; status: import('../generated/prisma/enums.js').MemberStatus; joinedAt: Date | null; createdAt: Date }): TeamMemberDto {
  return { userId: row.user.id, name: row.user.name, avatarUrl: row.user.avatarUrl, role: row.role, status: row.status, joinedAt: row.joinedAt, createdAt: row.createdAt };
}

function toTeamDto(t: {
  id: string;
  name: string;
  crestColor: string;
  area: string;
  level: TeamDto['level'];
  inviteCode: string;
  inviteExpiresAt: Date | null;
}): TeamDto {
  return {
    id: t.id,
    name: t.name,
    crestColor: t.crestColor,
    area: t.area,
    level: t.level,
    inviteCode: t.inviteCode,
    inviteExpiresAt: t.inviteExpiresAt,
  };
}

function pickCrestColor(name: string): string {
  let h = 0;
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return CREST_COLORS[h % CREST_COLORS.length];
}

function isUniqueViolation(e: unknown, field: string): boolean {
  if (
    !(e instanceof Prisma.PrismaClientKnownRequestError) ||
    e.code !== 'P2002'
  )
    return false;
  return JSON.stringify(e.meta ?? {}).includes(field);
}
