import type { ExecutionContext } from '@nestjs/common';
import type { Reflector } from '@nestjs/core';
import type { PrismaService } from '../prisma/prisma.service.js';
import { TeamMemberGuard } from './team-member.guard.js';

const TEAM = '11111111-1111-1111-1111-111111111111';

function ctx(params: Record<string, string>) {
  const req: Record<string, unknown> = { params, user: { userId: 'u1' } };
  return {
    req,
    context: {
      switchToHttp: () => ({ getRequest: () => req }),
      getHandler: () => null,
      getClass: () => null,
    } as unknown as ExecutionContext,
  };
}

function guard(member: unknown, roles?: string[]) {
  const prisma = {
    teamMember: { findUnique: vi.fn().mockResolvedValue(member) },
  };
  const reflector = { getAllAndOverride: vi.fn().mockReturnValue(roles) };
  return new TeamMemberGuard(
    prisma as unknown as PrismaService,
    reflector as unknown as Reflector,
  );
}

describe('TeamMemberGuard', () => {
  it('thành viên active → cho qua và gắn membership', async () => {
    const { req, context } = ctx({ teamId: TEAM });
    await expect(
      guard({ role: 'member', status: 'active' }).canActivate(context),
    ).resolves.toBe(true);
    expect(req.membership).toEqual({
      teamId: TEAM,
      userId: 'u1',
      role: 'member',
    });
  });

  it('không phải thành viên hoặc còn chờ duyệt → 404', async () => {
    await expect(
      guard(null).canActivate(ctx({ teamId: TEAM }).context),
    ).rejects.toMatchObject({ status: 404 });
    await expect(
      guard({ role: 'member', status: 'pending' }).canActivate(
        ctx({ teamId: TEAM }).context,
      ),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('teamId không phải uuid → 404, không truy vấn DB', async () => {
    const g = guard(null);
    await expect(
      g.canActivate(ctx({ teamId: 'abc' }).context),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('sai vai trò → 403', async () => {
    await expect(
      guard({ role: 'member', status: 'active' }, [
        'captain',
        'treasurer',
      ]).canActivate(ctx({ teamId: TEAM }).context),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('đúng vai trò → cho qua', async () => {
    await expect(
      guard({ role: 'treasurer', status: 'active' }, [
        'captain',
        'treasurer',
      ]).canActivate(ctx({ teamId: TEAM }).context),
    ).resolves.toBe(true);
  });
});
