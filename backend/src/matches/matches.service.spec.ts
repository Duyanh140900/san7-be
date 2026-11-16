import type { TeamMembership } from '../common/team-member.guard.js';
import type { NotificationsService } from '../notifications/notifications.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { feeKey, MatchesService } from './matches.service.js';

const HOUR = 3_600_000;
const capH: TeamMembership = { teamId: 'h', userId: 'cap-h', role: 'captain' };
const capA: TeamMembership = { teamId: 'a', userId: 'cap-a', role: 'captain' };
const memberH: TeamMembership = {
  teamId: 'h',
  userId: 'mem-h',
  role: 'member',
};

const team = (id: string, name: string) => ({
  id,
  name,
  crestColor: '#0066CC',
  area: 'Hà Đông',
  level: 'tb',
  createdById: `founder-${id}`,
});

function match(over: Record<string, unknown> = {}) {
  return {
    id: 'm1',
    postId: 'p1',
    homeTeamId: 'h',
    awayTeamId: 'a',
    startAt: new Date(Date.now() - 3 * HOUR),
    endAt: new Date(Date.now() - 1.5 * HOUR),
    location: 'Sân thử',
    status: 'scheduled',
    pitchPrice: 600_000n,
    ratioWin: 40,
    ratioLose: 60,
    homeScore: null,
    awayScore: null,
    reportedByTeamId: null,
    reportedAt: null,
    confirmedAt: null,
    createdAt: new Date(),
    homeTeam: team('h', 'FC Nhà'),
    awayTeam: team('a', 'FC Khách'),
    ...over,
  };
}

function setup() {
  const db = {
    $queryRaw: vi.fn().mockResolvedValue([]),
    match: { findFirst: vi.fn(), update: vi.fn() },
    matchPlayerStat: {
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn().mockResolvedValue(null),
      updateMany: vi.fn(),
      deleteMany: vi.fn(),
      createMany: vi.fn(),
    },
    event: { findFirst: vi.fn().mockResolvedValue({ id: 'ev' }) },
    fundTransaction: {
      create: vi.fn(),
      findUnique: vi.fn().mockResolvedValue(null),
    },
    team: { update: vi.fn() },
    teamMember: {
      // có include = lấy danh sách đội hình; không = người nhận thông báo
      findMany: vi.fn(
        (a: {
          include?: unknown;
          where: { teamId: string | { in: string[] } };
        }) => {
          if (a.include) {
            return Promise.resolve([
              {
                userId: 'u2',
                user: { name: 'Văn Nam', avatarUrl: null, position: null },
              },
              {
                userId: 'u1',
                user: {
                  name: 'Đức Hùng',
                  avatarUrl: null,
                  position: 'forward',
                },
              },
            ]);
          }
          const t = a.where.teamId;
          const ids = typeof t === 'string' ? [t] : t.in;
          return Promise.resolve(
            ids.map((id) => ({ userId: `mgr-${id}`, teamId: id })),
          );
        },
      ),
      count: vi.fn().mockResolvedValue(2),
    },
    notification: {
      createManyAndReturn: vi.fn(
        (a: { data: { userId: string; type: string }[] }) =>
          Promise.resolve(a.data.map((d) => ({ id: `n-${d.userId}`, ...d }))),
      ),
    },
    teamReview: {
      findUnique: vi.fn().mockResolvedValue(null),
      upsert: vi.fn(),
    },
  };
  const prisma = {
    ...db,
    $transaction: vi.fn((fn: (t: typeof db) => unknown) => fn(db)),
  };
  const notifications = { dispatch: vi.fn() };
  const realtime = { toTeam: vi.fn() };
  const service = new MatchesService(
    prisma as unknown as PrismaService,
    notifications as unknown as NotificationsService,
    realtime as unknown as RealtimeService,
  );
  return { service, db, notifications, realtime };
}

const notes = (db: ReturnType<typeof setup>['db']) =>
  db.notification.createManyAndReturn.mock.calls.flatMap(
    (c: unknown[]) =>
      (c[0] as { data: { userId: string; type: string }[] }).data,
  );

describe('MatchesService.setResult', () => {
  it('đội nhà nhập tỉ số: lưu người nhập, báo đội khách xác nhận, chưa trừ tiền', async () => {
    const { service, db, notifications } = setup();
    db.match.findFirst.mockResolvedValue(match());
    await service.setResult(capH, 'm1', { homeScore: 3, awayScore: 2 });
    expect(db.$queryRaw).toHaveBeenCalled();
    expect(db.match.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: expect.objectContaining({
        homeScore: 3,
        awayScore: 2,
        reportedByTeamId: 'h',
        confirmedAt: null,
      }),
    });
    expect(notes(db).map((n) => [n.userId, n.type])).toEqual([
      ['mgr-a', 'match.result_reported'],
    ]);
    expect(db.fundTransaction.create).not.toHaveBeenCalled();
    expect(notifications.dispatch).toHaveBeenCalled();
  });

  it('chưa kết thúc trận, trận huỷ, đã chốt → 409', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ endAt: new Date(Date.now() + HOUR) }),
    );
    await expect(
      service.setResult(capH, 'm1', { homeScore: 1, awayScore: 0 }),
    ).rejects.toMatchObject({ response: { code: 'match_not_finished' } });
    db.match.findFirst.mockResolvedValue(match({ status: 'cancelled' }));
    await expect(
      service.setResult(capH, 'm1', { homeScore: 1, awayScore: 0 }),
    ).rejects.toMatchObject({ response: { code: 'match_cancelled' } });
    db.match.findFirst.mockResolvedValue(
      match({
        confirmedAt: new Date(),
        reportedByTeamId: 'a',
        homeScore: 1,
        awayScore: 0,
      }),
    );
    await expect(
      service.setResult(capH, 'm1', { homeScore: 2, awayScore: 0 }),
    ).rejects.toMatchObject({
      status: 409,
      response: { code: 'result_confirmed' },
    });
    expect(db.match.update).not.toHaveBeenCalled();
  });

  it('trận của đội khác → 404', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(null);
    await expect(
      service.setResult({ ...capH, teamId: 'x' }, 'm1', {
        homeScore: 1,
        awayScore: 0,
      }),
    ).rejects.toMatchObject({ status: 404 });
    expect(db.match.findFirst.mock.calls[0][0].where).toEqual({
      id: 'm1',
      OR: [{ homeTeamId: 'x' }, { awayTeamId: 'x' }],
    });
  });

  it('đội kia nhập đúng tỉ số đã được báo → coi như xác nhận (chốt + trừ tiền)', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ homeScore: 3, awayScore: 2, reportedByTeamId: 'h' }),
    );
    await service.setResult(capA, 'm1', { homeScore: 3, awayScore: 2 });
    expect(db.match.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: expect.objectContaining({
        status: 'finished',
        confirmedAt: expect.any(Date),
      }),
    });
    expect(db.fundTransaction.create).toHaveBeenCalledTimes(2);
  });

  it('đội kia sửa tỉ số: người nhập đổi sang đội sửa, bắt đầu xác nhận lại', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ homeScore: 3, awayScore: 2, reportedByTeamId: 'h' }),
    );
    await service.setResult(capA, 'm1', { homeScore: 3, awayScore: 3 });
    expect(db.match.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: expect.objectContaining({
        reportedByTeamId: 'a',
        homeScore: 3,
        awayScore: 3,
      }),
    });
    expect(notes(db).map((n) => n.userId)).toEqual(['mgr-h']);
    expect(db.fundTransaction.create).not.toHaveBeenCalled();
  });

  it('tỉ số nhỏ đi: xoá số bàn đã ghi vượt tỉ số mới của đúng đội đó', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(match());
    db.matchPlayerStat.findMany.mockImplementation(
      (a: { where: { teamId: string } }) =>
        Promise.resolve(
          a.where.teamId === 'h'
            ? [
                { goals: 2, assists: 0 },
                { goals: 1, assists: 0 },
              ]
            : [{ goals: 1, assists: 1 }],
        ),
    );
    await service.setResult(capH, 'm1', { homeScore: 1, awayScore: 1 });
    // đội nhà ghi 3 bàn nhưng tỉ số mới 1 → xoá bàn thắng; đội khách vẫn hợp lệ
    expect(db.matchPlayerStat.updateMany).toHaveBeenCalledTimes(1);
    expect(db.matchPlayerStat.updateMany).toHaveBeenCalledWith({
      where: { matchId: 'm1', teamId: 'h' },
      data: { goals: 0 },
    });
  });
});

describe('MatchesService.confirm', () => {
  const reported = () =>
    match({
      homeScore: 3,
      awayScore: 2,
      reportedByTeamId: 'h',
      reportedAt: new Date(),
    });

  it('đội khách xác nhận: chốt, trừ tiền sân hai đội theo tỷ lệ 40–60, báo đội nhà', async () => {
    const { service, db, realtime } = setup();
    db.match.findFirst.mockResolvedValue(reported());
    await service.confirm(capA, 'm1');

    expect(db.match.update).toHaveBeenCalledWith({
      where: { id: 'm1' },
      data: expect.objectContaining({ status: 'finished' }),
    });
    const tx = db.fundTransaction.create.mock.calls.map((c) => c[0].data);
    expect(tx).toEqual([
      expect.objectContaining({
        teamId: 'h',
        type: 'expense',
        amount: 240_000n, // đội nhà thắng trả 40%
        category: 'Tiền sân',
        paid: true,
        eventId: 'ev',
        createdById: 'founder-h',
        autoKey: feeKey('m1', 'h'),
      }),
      expect.objectContaining({
        teamId: 'a',
        amount: 360_000n,
        autoKey: feeKey('m1', 'a'),
      }),
    ]);
    expect(db.team.update).toHaveBeenCalledWith({
      where: { id: 'h' },
      data: { fundBalance: { decrement: 240_000n } },
    });
    expect(db.team.update).toHaveBeenCalledWith({
      where: { id: 'a' },
      data: { fundBalance: { decrement: 360_000n } },
    });
    expect(notes(db).map((n) => [n.userId, n.type])).toEqual([
      ['mgr-h', 'match.result_confirmed'],
    ]);
    expect(realtime.toTeam).toHaveBeenCalledWith('h', 'funds.changed', {});
    expect(realtime.toTeam).toHaveBeenCalledWith('a', 'funds.changed', {});
  });

  it('kèo không chia tiền sân: chốt nhưng không trừ quỹ', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue({
      ...reported(),
      pitchPrice: null,
      ratioWin: null,
      ratioLose: null,
    });
    await service.confirm(capA, 'm1');
    expect(db.match.update).toHaveBeenCalled();
    expect(db.fundTransaction.create).not.toHaveBeenCalled();
    expect(db.team.update).not.toHaveBeenCalled();
  });

  it('thua trả sân: đội thắng không bị trừ gì', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue({
      ...reported(),
      ratioWin: 0,
      ratioLose: 100,
    });
    await service.confirm(capA, 'm1');
    const tx = db.fundTransaction.create.mock.calls.map((c) => c[0].data);
    expect(tx).toHaveLength(1);
    expect(tx[0]).toMatchObject({ teamId: 'a', amount: 600_000n });
  });

  it('tự xác nhận tỉ số mình nhập → 409; chưa ai nhập → 409', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(reported());
    await expect(service.confirm(capH, 'm1')).rejects.toMatchObject({
      response: { code: 'own_report' },
    });
    db.match.findFirst.mockResolvedValue(match());
    await expect(service.confirm(capA, 'm1')).rejects.toMatchObject({
      response: { code: 'no_result' },
    });
    expect(db.fundTransaction.create).not.toHaveBeenCalled();
  });

  it('gọi lại sau khi đã chốt: không trừ tiền lần hai', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue({
      ...reported(),
      confirmedAt: new Date(),
    });
    await service.confirm(capA, 'm1');
    expect(db.match.update).not.toHaveBeenCalled();
    expect(db.fundTransaction.create).not.toHaveBeenCalled();
  });
});

describe('MatchesService.setStats', () => {
  const withScore = () =>
    match({ homeScore: 3, awayScore: 2, reportedByTeamId: 'h' });
  const uid = (n: number) => `00000000-0000-4000-8000-00000000000${n}`;

  it('thay toàn bộ số liệu của đội mình, gộp cầu thủ hay nhất vào cùng dòng', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(withScore());
    db.teamMember.count.mockResolvedValue(3);
    await service.setStats(capH, 'm1', {
      players: [
        { userId: uid(1), goals: 2, assists: 0 },
        { userId: uid(2), goals: 0, assists: 1 },
        { userId: uid(3), goals: 0, assists: 0 }, // dòng trống bị bỏ
      ],
      mvpUserId: uid(1),
    });
    expect(db.matchPlayerStat.deleteMany).toHaveBeenCalledWith({
      where: { matchId: 'm1', teamId: 'h' },
    });
    expect(db.matchPlayerStat.createMany.mock.calls[0][0].data).toEqual([
      {
        matchId: 'm1',
        teamId: 'h',
        userId: uid(1),
        goals: 2,
        assists: 0,
        mvp: true,
      },
      {
        matchId: 'm1',
        teamId: 'h',
        userId: uid(2),
        goals: 0,
        assists: 1,
        mvp: false,
      },
    ]);
  });

  it('cầu thủ hay nhất không ghi bàn vẫn được lưu', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(withScore());
    db.teamMember.count.mockResolvedValue(1);
    await service.setStats(capH, 'm1', { players: [], mvpUserId: uid(4) });
    expect(db.matchPlayerStat.createMany.mock.calls[0][0].data).toEqual([
      {
        matchId: 'm1',
        teamId: 'h',
        userId: uid(4),
        goals: 0,
        assists: 0,
        mvp: true,
      },
    ]);
  });

  it('chặn: chưa có tỉ số, tổng bàn vượt tỉ số, trùng cầu thủ, không thuộc đội', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(match());
    await expect(
      service.setStats(capH, 'm1', { players: [] }),
    ).rejects.toMatchObject({ response: { code: 'result_required' } });

    db.match.findFirst.mockResolvedValue(withScore());
    await expect(
      service.setStats(capH, 'm1', {
        players: [
          { userId: uid(1), goals: 2, assists: 0 },
          { userId: uid(2), goals: 2, assists: 0 },
        ],
      }),
    ).rejects.toMatchObject({ response: { code: 'stats_exceed_score' } });

    await expect(
      service.setStats(capH, 'm1', {
        players: [
          { userId: uid(1), goals: 1, assists: 0 },
          { userId: uid(1), goals: 1, assists: 0 },
        ],
      }),
    ).rejects.toMatchObject({ response: { code: 'duplicate_player' } });

    db.teamMember.count.mockResolvedValue(0);
    await expect(
      service.setStats(capH, 'm1', {
        players: [{ userId: uid(9), goals: 1, assists: 0 }],
      }),
    ).rejects.toMatchObject({ response: { code: 'not_member' } });
    expect(db.matchPlayerStat.deleteMany).not.toHaveBeenCalled();
  });

  it('cầu thủ đã được đội kia ghi số liệu trong trận này → 409 (một người một đội mỗi trận)', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(withScore());
    db.teamMember.count.mockResolvedValue(1);
    db.matchPlayerStat.findFirst.mockResolvedValue({ userId: uid(1) });
    await expect(
      service.setStats(capH, 'm1', {
        players: [{ userId: uid(1), goals: 1, assists: 0 }],
      }),
    ).rejects.toMatchObject({
      status: 409,
      response: { code: 'player_in_other_team' },
    });
    expect(db.matchPlayerStat.findFirst.mock.calls[0][0].where).toMatchObject({
      matchId: 'm1',
      teamId: { not: 'h' },
    });
    expect(db.matchPlayerStat.deleteMany).not.toHaveBeenCalled();
  });

  it('đội khách chỉ bị giới hạn bởi tỉ số của đội khách', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(withScore()); // khách 2 bàn
    db.teamMember.count.mockResolvedValue(1);
    await expect(
      service.setStats(capA, 'm1', {
        players: [{ userId: uid(1), goals: 3, assists: 0 }],
      }),
    ).rejects.toMatchObject({ response: { code: 'stats_exceed_score' } });
    await service.setStats(capA, 'm1', {
      players: [{ userId: uid(1), goals: 2, assists: 0 }],
    });
    expect(db.matchPlayerStat.deleteMany).toHaveBeenCalledWith({
      where: { matchId: 'm1', teamId: 'a' },
    });
  });
});

describe('MatchesService.review', () => {
  it('lưu đánh giá đội đối thủ, sửa lại được (upsert theo trận + đội)', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(match());
    await service.review(capH, 'm1', {
      reputation: 5,
      fairplay: 4,
      tags: ['on_time', 'good_play'],
      comment: 'Đá đẹp',
    });
    const call = db.teamReview.upsert.mock.calls[0][0];
    expect(call.where).toEqual({
      matchId_fromTeamId: { matchId: 'm1', fromTeamId: 'h' },
    });
    expect(call.create).toMatchObject({
      toTeamId: 'a',
      fromTeamId: 'h',
      createdById: 'cap-h',
      reputation: 5,
      fairplay: 4,
      tags: ['on_time', 'good_play'],
      comment: 'Đá đẹp',
    });
    // đội khách đánh giá đội nhà
    await service.review(capA, 'm1', { reputation: 3, fairplay: 3, tags: [] });
    expect(db.teamReview.upsert.mock.calls[1][0].create).toMatchObject({
      toTeamId: 'h',
      comment: null,
    });
  });

  it('chưa kết thúc trận → 409', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ endAt: new Date(Date.now() + HOUR) }),
    );
    await expect(
      service.review(capH, 'm1', { reputation: 5, fairplay: 5, tags: [] }),
    ).rejects.toMatchObject({ response: { code: 'match_not_finished' } });
    expect(db.teamReview.upsert).not.toHaveBeenCalled();
  });
});

describe('MatchesService.detail', () => {
  it('đội hình kèm số liệu, trạng thái kết quả theo đội xem, quyền theo vai trò', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ homeScore: 3, awayScore: 2, reportedByTeamId: 'h' }),
    );
    db.matchPlayerStat.findMany.mockResolvedValue([
      { userId: 'u1', goals: 2, assists: 0, mvp: true },
    ]);
    db.fundTransaction.findUnique.mockResolvedValue({ amount: 240_000n });

    const asHome = await service.detail(capH, 'm1');
    expect(asHome.resultState).toBe('awaiting_opponent');
    expect(asHome.canReport).toBe(true);
    expect(asHome.myFee).toBe(240_000);
    expect(asHome.pitchPrice).toBe(600_000);
    // sắp theo tên tiếng Việt
    expect(asHome.roster.map((p) => p.name)).toEqual(['Đức Hùng', 'Văn Nam']);
    expect(asHome.roster[0]).toMatchObject({ goals: 2, mvp: true });
    expect(asHome.roster[1]).toMatchObject({ goals: 0, mvp: false });

    expect((await service.detail(capA, 'm1')).resultState).toBe('awaiting_me');
    const asMember = await service.detail(memberH, 'm1');
    expect(asMember.canReport).toBe(false);
    expect(asMember.canEdit).toBe(false);
  });

  it('đã chốt thì không còn sửa tỉ số nhưng vẫn sửa thống kê và đánh giá', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({
        homeScore: 1,
        awayScore: 0,
        reportedByTeamId: 'a',
        confirmedAt: new Date(),
      }),
    );
    const d = await service.detail(capH, 'm1');
    expect(d.resultState).toBe('confirmed');
    expect(d.canReport).toBe(false);
    expect(d.canEdit).toBe(true);
  });

  it('chưa kết thúc: chưa được nhập gì', async () => {
    const { service, db } = setup();
    db.match.findFirst.mockResolvedValue(
      match({ endAt: new Date(Date.now() + HOUR) }),
    );
    const d = await service.detail(capH, 'm1');
    expect(d.ended).toBe(false);
    expect(d.canReport).toBe(false);
    expect(d.canEdit).toBe(false);
  });
});
