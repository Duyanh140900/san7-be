import { AppError } from '../common/errors.js';
import { MatchStatus } from '../generated/prisma/enums.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { ChatService } from './chat.service.js';

const matchId = '11111111-1111-4111-8111-111111111111';
const homeTeamId = '22222222-2222-4222-8222-222222222222';
const awayTeamId = '33333333-3333-4333-8333-333333333333';
const userId = '44444444-4444-4444-8444-444444444444';
const now = new Date('2026-11-16T12:00:00.000Z');

function errorIs(status: number, code: string) {
  return (e: unknown) =>
    e instanceof AppError &&
    e.getStatus() === status &&
    (e.getResponse() as { code: string }).code === code;
}

function row(overrides: Record<string, unknown> = {}) {
  return {
    id: 'm1',
    matchId,
    teamId: homeTeamId,
    userId,
    body: 'Mấy giờ có mặt?',
    createdAt: now,
    user: { id: userId, name: 'Anh A', avatarUrl: null },
    ...overrides,
  };
}

function setup(opts: { member?: unknown; match?: unknown } = {}) {
  const prisma = {
    match: {
      findUnique: vi
        .fn()
        .mockResolvedValue(
          'match' in opts
            ? opts.match
            : { homeTeamId, awayTeamId, status: MatchStatus.scheduled },
        ),
    },
    teamMember: {
      findFirst: vi
        .fn()
        .mockResolvedValue(
          'member' in opts ? opts.member : { teamId: homeTeamId },
        ),
    },
    matchMessage: {
      create: vi.fn().mockResolvedValue(row()),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  const realtime = { toMatch: vi.fn() };
  return {
    service: new ChatService(
      prisma as unknown as PrismaService,
      realtime as unknown as RealtimeService,
    ),
    prisma,
    realtime,
  };
}

describe('ChatService - chat hai đội', () => {
  it('thành viên active của một trong hai đội gửi được; ghi đội người gửi và phát realtime', async () => {
    const { service, prisma, realtime } = setup();
    const result = await service.send(userId, matchId, {
      body: 'Mấy giờ có mặt?',
    });

    expect(prisma.teamMember.findFirst).toHaveBeenCalledWith({
      where: {
        userId,
        status: 'active',
        teamId: { in: [homeTeamId, awayTeamId] },
      },
      select: { teamId: true },
    });
    expect(prisma.matchMessage.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { matchId, teamId: homeTeamId, userId, body: 'Mấy giờ có mặt?' },
      }),
    );
    expect(result.sender.name).toBe('Anh A');
    expect(realtime.toMatch).toHaveBeenCalledWith(matchId, 'chat.message', {
      message: result,
    });
  });

  it('người ngoài hai đội không gửi được (403) và không ghi gì', async () => {
    const { service, prisma, realtime } = setup({ member: null });
    await expect(
      service.send(userId, matchId, { body: 'xin chào' }),
    ).rejects.toSatisfy(errorIs(403, 'chat_forbidden'));
    expect(prisma.matchMessage.create).not.toHaveBeenCalled();
    expect(realtime.toMatch).not.toHaveBeenCalled();
  });

  it('người ngoài hai đội không đọc được (403)', async () => {
    const { service, prisma } = setup({ member: null });
    await expect(service.list(userId, matchId, {})).rejects.toBeInstanceOf(
      AppError,
    );
    expect(prisma.matchMessage.findMany).not.toHaveBeenCalled();
  });

  it('trận không tồn tại → 404', async () => {
    const { service } = setup({ match: null });
    await expect(service.list(userId, matchId, {})).rejects.toSatisfy(
      errorIs(404, 'match_not_found'),
    );
  });

  it('trận đã huỷ: không gửi được (409) nhưng vẫn đọc được', async () => {
    const { service } = setup({
      match: { homeTeamId, awayTeamId, status: MatchStatus.cancelled },
    });
    await expect(
      service.send(userId, matchId, { body: 'alo' }),
    ).rejects.toSatisfy(errorIs(409, 'match_cancelled'));
    await expect(service.list(userId, matchId, {})).resolves.toEqual({
      items: [],
      nextCursor: undefined,
    });
  });

  it('phân trang cursor: lấy limit+1, trả nextCursor khi còn trang sau', async () => {
    const { service, prisma } = setup();
    prisma.matchMessage.findMany.mockResolvedValue([
      row({ id: 'a' }),
      row({ id: 'b' }),
      row({ id: 'c' }),
    ]);
    const page = await service.list(userId, matchId, { limit: 2, cursor: 'z' });

    expect(prisma.matchMessage.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { matchId },
        take: 3,
        cursor: { id: 'z' },
        skip: 1,
      }),
    );
    expect(page.items.map((m) => m.id)).toEqual(['a', 'b']);
    expect(page.nextCursor).toBe('b');
  });
});
