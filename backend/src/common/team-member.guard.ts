import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  HttpStatus,
  Injectable,
  SetMetadata,
  UseGuards,
  applyDecorators,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ApiBearerAuth, ApiParam } from '@nestjs/swagger';
import type { TeamRole } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { AuthUser } from './auth.decorators.js';
import { AppError } from './errors.js';

export const TEAM_ROLES_KEY = 'teamRoles';

/** Chỉ các vai trò này trong đội mới được gọi endpoint. Không gắn = mọi thành viên active. */
export const TeamRoles = (...roles: TeamRole[]) =>
  SetMetadata(TEAM_ROLES_KEY, roles);

export interface TeamMembership {
  teamId: string;
  userId: string;
  role: TeamRole;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Kiểm tra người gọi là thành viên active của đội `:teamId` (và có vai trò phù hợp).
 * Dùng cho mọi controller dưới /teams/:teamId.
 */
@Injectable()
export class TeamMemberGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<{
      params: Record<string, string>;
      user: AuthUser;
      membership?: TeamMembership;
    }>();
    const teamId = req.params.teamId;
    const notFound = new AppError(
      HttpStatus.NOT_FOUND,
      'team_not_found',
      'Không tìm thấy đội',
    );
    if (!teamId || !UUID.test(teamId)) throw notFound;

    const member = await this.prisma.teamMember.findUnique({
      where: { teamId_userId: { teamId, userId: req.user.userId } },
      select: { role: true, status: true },
    });
    // Không tiết lộ đội có tồn tại hay không với người ngoài
    if (!member || member.status !== 'active') throw notFound;

    const roles = this.reflector.getAllAndOverride<TeamRole[] | undefined>(
      TEAM_ROLES_KEY,
      [ctx.getHandler(), ctx.getClass()],
    );
    if (roles?.length && !roles.includes(member.role)) {
      throw new AppError(
        HttpStatus.FORBIDDEN,
        'team_role_required',
        'Bạn không có quyền làm việc này trong đội',
      );
    }
    req.membership = { teamId, userId: req.user.userId, role: member.role };
    return true;
  }
}

/** Thành viên đã được TeamMemberGuard kiểm tra. */
export const CurrentMember = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): TeamMembership => {
    const req = ctx.switchToHttp().getRequest<{ membership: TeamMembership }>();
    return req.membership;
  },
);

/** Gắn cho controller dưới /teams/:teamId: kiểm tra thành viên + khai báo tham số cho OpenAPI. */
export const TeamScoped = () =>
  applyDecorators(
    UseGuards(TeamMemberGuard),
    ApiBearerAuth(),
    ApiParam({ name: 'teamId', type: String, format: 'uuid' }),
  );
