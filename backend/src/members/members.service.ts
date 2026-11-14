import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { TeamRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type { MemberDto, MemberListDto } from './members.dto.js';

const ROLE_ORDER: Record<TeamRole, number> = {
  captain: 0,
  vice: 1,
  treasurer: 2,
  member: 3,
};

const MANAGERS: TeamRole[] = ['captain', 'vice'];

@Injectable()
export class MembersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async list(me: TeamMembership): Promise<MemberListDto> {
    const rows = await this.prisma.teamMember.findMany({
      where: { teamId: me.teamId },
      include: { user: true },
    });
    const toDto = (m: (typeof rows)[number]): MemberDto => ({
      userId: m.userId,
      name: m.user.name,
      avatarUrl: m.user.avatarUrl,
      position: m.user.position,
      shirtNumber: m.user.shirtNumber,
      role: m.role,
      status: m.status,
      joinedAt: m.joinedAt,
      requestedAt: m.createdAt,
    });
    const active = rows
      .filter((m) => m.status === 'active')
      .sort(
        (a, b) =>
          ROLE_ORDER[a.role] - ROLE_ORDER[b.role] ||
          a.user.name.localeCompare(b.user.name, 'vi'),
      )
      .map(toDto);
    const pending = MANAGERS.includes(me.role)
      ? rows
          .filter((m) => m.status === 'pending')
          .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
          .map(toDto)
      : [];
    return { active, pending };
  }

  async approve(me: TeamMembership, userId: string): Promise<void> {
    const { count } = await this.prisma.teamMember.updateMany({
      where: { teamId: me.teamId, userId, status: 'pending' },
      data: { status: 'active', joinedAt: new Date() },
    });
    if (count === 0) throw this.requestNotFound();
    this.changed(me.teamId);
  }

  async reject(me: TeamMembership, userId: string): Promise<void> {
    const { count } = await this.prisma.teamMember.deleteMany({
      where: { teamId: me.teamId, userId, status: 'pending' },
    });
    if (count === 0) throw this.requestNotFound();
    this.changed(me.teamId);
  }

  /** Đổi vai trò (chỉ đội trưởng). Trao quyền đội trưởng thì người trao thành đội phó. */
  async changeRole(
    me: TeamMembership,
    userId: string,
    role: TeamRole,
  ): Promise<void> {
    if (userId === me.userId) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'cannot_change_own_role',
        'Không tự đổi vai trò của mình. Trao đội trưởng cho người khác nếu muốn.',
      );
    }
    await this.prisma.$transaction(async (tx) => {
      const { count } = await tx.teamMember.updateMany({
        where: { teamId: me.teamId, userId, status: 'active' },
        data: { role },
      });
      if (count === 0) throw this.memberNotFound();
      if (role === 'captain') {
        await tx.teamMember.update({
          where: { teamId_userId: { teamId: me.teamId, userId: me.userId } },
          data: { role: 'vice' },
        });
      }
    });
    this.changed(me.teamId);
  }

  /** Đội trưởng mời một thành viên ra khỏi đội. */
  async remove(me: TeamMembership, userId: string): Promise<void> {
    if (userId === me.userId) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'use_leave',
        'Dùng chức năng rời đội để tự rời',
      );
    }
    const { count } = await this.prisma.teamMember.deleteMany({
      where: { teamId: me.teamId, userId, status: 'active' },
    });
    if (count === 0) throw this.memberNotFound();
    this.changed(me.teamId);
  }

  async leave(me: TeamMembership): Promise<void> {
    if (me.role === 'captain') {
      throw new AppError(
        HttpStatus.CONFLICT,
        'captain_cannot_leave',
        'Trao quyền đội trưởng cho người khác trước khi rời đội',
      );
    }
    await this.prisma.teamMember.delete({
      where: { teamId_userId: { teamId: me.teamId, userId: me.userId } },
    });
    this.changed(me.teamId);
  }

  private changed(teamId: string) {
    this.realtime.toTeam(teamId, 'members.changed', {});
  }

  private requestNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'join_request_not_found',
      'Không tìm thấy yêu cầu vào đội',
    );
  }

  private memberNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'member_not_found',
      'Không tìm thấy thành viên',
    );
  }
}
