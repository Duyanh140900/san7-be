import type { PrismaService } from '../prisma/prisma.service.js';
import { teamStats } from '../posts/team-stats.js';
import { HonorsService } from './honors.service.js';
import { promptMatchResult } from './match-prompt.js';
import { TeamProfileService } from './team-profile.service.js';
import { recentMatches, reviewSummaries, teamRecords } from './team-record.js';

const m = (
  id: string,
  home: string,
  away: string,
  hs: number,
  as: number,
  daysAgo: number,
) => ({
  id,
  homeTeamId: home,
  awayTeamId: away,
  homeScore: hs,
  awayScore: as,
  startAt: new Date(Date.now() - daysAgo * 86_400_000),
});

// A: thắng B 3-2 (7 ngày trước), hoà C 1-1 (5), thua B 0-1 khi làm khách (3), thắng C 2-0 (1)
const matches = [
  m('4', 'a', 'c', 2, 0, 1),
  m('3', 'b', 'a', 1, 0, 3),
  m('2', 'a', 'c', 1, 1, 5),
  m('1', 'a', 'b', 3, 2, 7),
];

describe('teamRecords', () => {
  it('thắng/hoà/thua, hiệu số và phong độ (mới nhất trước) của từng đội', async () => {
    const db = { match: { findMany: vi.fn().mockResolvedValue(matches) } };
    const r = await teamRecords(db as never, ['a', 'b']);
    expect(r.get('a')).toEqual({
      played: 4,
      wins: 2,
      draws: 1,
      losses: 1,
      goalsFor: 6,
      goalsAgainst: 4,
      form: ['W', 'L', 'D', 'W'],
    });
    expect(r.get('b')).toMatchObject({
      played: 2,
      wins: 1,
      losses: 1,
      form: ['W', 'L'],
    });
    // chỉ trận đã xác nhận tỉ số
    expect(db.match.findMany.mock.calls[0][0].where).toMatchObject({
      confirmedAt: { not: null },
    });
  });

  it('đội chưa đá trận nào có thành tích rỗng', async () => {
    const db = { match: { findMany: vi.fn().mockResolvedValue([]) } };
    expect((await teamRecords(db as never, ['z'])).get('z')).toMatchObject({
      played: 0,
      form: [],
    });
  });

  it('phong độ chỉ giữ 5 trận gần nhất', async () => {
    const many = Array.from({ length: 8 }, (_, i) =>
      m(`${i}`, 'a', 'b', 1, 0, i + 1),
    );
    const db = { match: { findMany: vi.fn().mockResolvedValue(many) } };
    expect((await teamRecords(db as never, ['a'])).get('a')!.form).toHaveLength(
      5,
    );
  });
});

describe('recentMatches', () => {
  it('đổi góc nhìn theo sân nhà/khách', async () => {
    const db = { match: { findMany: vi.fn().mockResolvedValue(matches) } };
    const r = await recentMatches(db as never, 'a', 2);
    expect(r).toHaveLength(2);
    expect(r[0]).toMatchObject({
      opponentId: 'c',
      goalsFor: 2,
      goalsAgainst: 0,
      outcome: 'W',
    });
    // trận làm khách, thua 0–1
    expect(r[1]).toMatchObject({
      opponentId: 'b',
      goalsFor: 0,
      goalsAgainst: 1,
      outcome: 'L',
    });
  });
});

describe('reviewSummaries', () => {
  it('trung bình 1 chữ số thập phân và % đánh giá "Đúng giờ"', async () => {
    const db = {
      teamReview: {
        groupBy: vi
          .fn()
          .mockResolvedValueOnce([
            {
              toTeamId: 'a',
              _count: { _all: 3 },
              _avg: { reputation: 4.666, fairplay: 4 },
            },
          ])
          .mockResolvedValueOnce([{ toTeamId: 'a', _count: { _all: 2 } }]),
      },
    };
    const r = await reviewSummaries(db as never, ['a', 'b']);
    expect(r.get('a')).toEqual({
      count: 3,
      reputation: 4.7,
      fairplay: 4,
      onTimePercent: 67,
    });
    expect(r.get('b')).toEqual({
      count: 0,
      reputation: null,
      fairplay: null,
      onTimePercent: null,
    });
  });
});

describe('teamStats (so sánh đội nhận kèo)', () => {
  it('đối đầu với đội đăng kèo, thành viên, uy tín', async () => {
    const db = {
      teamMember: {
        groupBy: vi
          .fn()
          .mockResolvedValue([{ teamId: 'b', _count: { _all: 12 } }]),
      },
      // lần đầu: thành tích của b; lần hai: các trận của đội đăng kèo (a)
      match: {
        findMany: vi
          .fn()
          .mockImplementation(
            (args: { where: { OR: { homeTeamId?: { in: string[] } }[] } }) => {
              const ids = args.where.OR[0].homeTeamId!.in;
              return Promise.resolve(
                ids.includes('a')
                  ? matches
                  : matches.filter(
                      (x) => x.homeTeamId === 'b' || x.awayTeamId === 'b',
                    ),
              );
            },
          ),
      },
      teamReview: {
        groupBy: vi
          .fn()
          .mockResolvedValueOnce([
            {
              toTeamId: 'b',
              _count: { _all: 4 },
              _avg: { reputation: 4.5, fairplay: 4 },
            },
          ])
          .mockResolvedValueOnce([{ toTeamId: 'b', _count: { _all: 3 } }]),
      },
    };
    const s = (await teamStats(db as never, 'a', ['b'])).get('b')!;
    expect(s).toMatchObject({
      memberCount: 12,
      matchesPlayed: 2,
      headToHead: 2, // a–b hai lần
      h2hOwnerWins: 1, // a thắng 3–2
      h2hOwnerLosses: 1, // a thua 0–1
      reputation: 4.5,
      reviewCount: 4,
      onTimePercent: 75,
    });
  });

  it('không có đội nào thì không truy vấn', async () => {
    const db = { teamMember: { groupBy: vi.fn() } };
    expect((await teamStats(db as never, 'a', [])).size).toBe(0);
    expect(db.teamMember.groupBy).not.toHaveBeenCalled();
  });
});

describe('HonorsService', () => {
  const brief = (id: string) => ({
    id,
    name: `Đội ${id}`,
    crestColor: '#000000',
    area: 'Hà Nội',
    level: 'tb',
  });

  function setup(opts: { sums: unknown[]; mvps: unknown[] }) {
    const prisma = {
      matchPlayerStat: {
        groupBy: vi
          .fn()
          .mockResolvedValueOnce(opts.sums)
          .mockResolvedValueOnce(opts.mvps),
      },
      user: {
        findMany: vi.fn().mockResolvedValue([
          { id: 'u1', name: 'Đức Hùng', avatarUrl: null, position: 'forward' },
          { id: 'u2', name: 'Tiến Linh', avatarUrl: null, position: null },
          { id: 'u3', name: 'Văn Nam', avatarUrl: null, position: null },
        ]),
      },
      team: { findMany: vi.fn().mockResolvedValue([brief('a'), brief('b')]) },
      match: { findMany: vi.fn().mockResolvedValue([]) },
      teamReview: { groupBy: vi.fn().mockResolvedValue([]) },
    };
    return {
      service: new HonorsService(prisma as unknown as PrismaService),
      prisma,
    };
  }

  const sums = [
    { userId: 'u1', teamId: 'a', _sum: { goals: 9, assists: 4 } },
    { userId: 'u2', teamId: 'b', _sum: { goals: 7, assists: 1 } },
    { userId: 'u3', teamId: 'a', _sum: { goals: 0, assists: 6 } },
  ];

  it('vua phá lưới xếp theo bàn thắng, bỏ người chưa ghi bàn', async () => {
    const { service } = setup({
      sums,
      mvps: [{ userId: 'u1', teamId: 'a', _count: { _all: 3 } }],
    });
    const r = await service.get({ month: '2026-11' });
    expect(r.month).toBe('2026-11');
    expect(r.scorers.map((p) => [p.name, p.goals])).toEqual([
      ['Đức Hùng', 9],
      ['Tiến Linh', 7],
    ]);
    expect(r.scorers[0].team.name).toBe('Đội a');
  });

  it('cầu thủ của tháng: nhiều MVP nhất, rồi tới bàn thắng', async () => {
    const { service } = setup({
      sums,
      mvps: [
        { userId: 'u2', teamId: 'b', _count: { _all: 2 } },
        { userId: 'u1', teamId: 'a', _count: { _all: 1 } },
      ],
    });
    const r = await service.get({ month: '2026-11' });
    expect(r.playerOfMonth).toMatchObject({
      name: 'Tiến Linh',
      mvps: 2,
      goals: 7,
    });
  });

  it('chỉ tính trận đã xác nhận trong tháng (giờ VN)', async () => {
    const { service, prisma } = setup({ sums: [], mvps: [] });
    const r = await service.get({ month: '2026-11' });
    expect(r.scorers).toEqual([]);
    expect(r.playerOfMonth).toBeUndefined();
    const where = prisma.matchPlayerStat.groupBy.mock.calls[0][0].where;
    expect(where.match.confirmedAt).toEqual({ not: null });
    expect(where.match.startAt.gte.toISOString()).toBe(
      '2026-10-31T17:00:00.000Z',
    );
    expect(where.match.startAt.lt.toISOString()).toBe(
      '2026-11-30T17:00:00.000Z',
    );
  });

  it('tháng sai định dạng → 400', async () => {
    const { service } = setup({ sums: [], mvps: [] });
    await expect(service.get({ month: '2026-13' })).rejects.toMatchObject({
      status: 400,
      response: { code: 'invalid_month' },
    });
  });

  it('danh hiệu đội: bất bại từ 5 trận, fair-play từ 5 đánh giá điểm ≥ 4,5', async () => {
    const { service, prisma } = setup({ sums: [], mvps: [] });
    const form = Array.from({ length: 5 }, (_, i) =>
      m(`${i}`, 'a', 'b', 1, 0, i + 1),
    );
    prisma.match.findMany.mockResolvedValue(form);
    prisma.teamReview.groupBy
      .mockResolvedValueOnce([
        {
          toTeamId: 'a',
          _count: { _all: 6 },
          _avg: { reputation: 4, fairplay: 4.8 },
        },
      ])
      .mockResolvedValueOnce([]);
    const r = await service.get({ month: '2026-11', teamId: 'a' });
    expect(r.teamBadges).toEqual([
      { type: 'unbeaten', value: 5 },
      { type: 'fairplay', value: 4.8 },
    ]);
  });

  it('chưa đủ điều kiện thì không có danh hiệu', async () => {
    const { service, prisma } = setup({ sums: [], mvps: [] });
    prisma.match.findMany.mockResolvedValue([m('1', 'a', 'b', 0, 2, 1)]);
    const r = await service.get({ month: '2026-11', teamId: 'a' });
    expect(r.teamBadges).toEqual([]);
  });
});

describe('TeamProfileService', () => {
  it('gom thành tích, uy tín, nhãn phổ biến nhất, nhận xét và trận gần đây', async () => {
    const brief = (id: string) => ({
      id,
      name: `Đội ${id}`,
      crestColor: '#000000',
      area: 'Hà Nội',
      level: 'tb',
    });
    const prisma = {
      team: {
        findUnique: vi.fn().mockResolvedValue({
          ...brief('a'),
          createdAt: new Date('2022-05-01T00:00:00Z'),
        }),
        findMany: vi.fn().mockResolvedValue([brief('b'), brief('c')]),
      },
      teamMember: { count: vi.fn().mockResolvedValue(16) },
      match: { findMany: vi.fn().mockResolvedValue(matches) },
      teamReview: {
        groupBy: vi
          .fn()
          .mockResolvedValueOnce([
            {
              toTeamId: 'a',
              _count: { _all: 3 },
              _avg: { reputation: 5, fairplay: 4 },
            },
          ])
          .mockResolvedValueOnce([{ toTeamId: 'a', _count: { _all: 3 } }]),
        findMany: vi
          .fn()
          .mockResolvedValueOnce([
            { tags: ['on_time', 'good_play'] },
            { tags: ['on_time'] },
            { tags: ['on_time', 'friendly'] },
          ])
          .mockResolvedValueOnce([
            {
              fromTeam: brief('b'),
              reputation: 5,
              fairplay: 4,
              comment: 'Đá fair',
              createdAt: new Date(),
            },
          ]),
      },
    };
    const p = await new TeamProfileService(
      prisma as unknown as PrismaService,
    ).get('a');
    expect(p.sinceYear).toBe(2022);
    expect(p.memberCount).toBe(16);
    expect(p.record).toMatchObject({ played: 4, wins: 2, draws: 1, losses: 1 });
    expect(p).toMatchObject({
      reviewCount: 3,
      reputation: 5,
      fairplay: 4,
      onTimePercent: 100,
    });
    expect(p.tags[0]).toEqual({ tag: 'on_time', count: 3 });
    expect(p.reviews[0].comment).toBe('Đá fair');
    expect(p.recentMatches.map((x) => x.opponent.name)).toEqual([
      'Đội c',
      'Đội b',
      'Đội c',
      'Đội b',
    ]);
    expect(p.team).not.toHaveProperty('createdAt');
  });

  it('không có đội → 404', async () => {
    const prisma = { team: { findUnique: vi.fn().mockResolvedValue(null) } };
    await expect(
      new TeamProfileService(prisma as unknown as PrismaService).get('x'),
    ).rejects.toMatchObject({ status: 404 });
  });
});

describe('promptMatchResult', () => {
  const base = {
    id: 'm1',
    status: 'scheduled',
    homeScore: null,
    endAt: new Date(Date.now() - 60_000),
    startAt: new Date(Date.now() - 3_600_000),
    homeTeam: { id: 'h', name: 'FC Nhà' },
    awayTeam: { id: 'a', name: 'FC Khách' },
  };

  function setup(match: unknown) {
    const tx = {
      match: { findUnique: vi.fn().mockResolvedValue(match) },
      teamMember: {
        findMany: vi.fn((args: { where: { teamId: { in: string[] } } }) =>
          Promise.resolve(
            args.where.teamId.in.map((id) => ({
              userId: `mgr-${id}`,
              teamId: id,
            })),
          ),
        ),
      },
      notification: {
        createManyAndReturn: vi.fn(
          (a: { data: { userId: string; title: string }[] }) =>
            Promise.resolve(a.data.map((d) => ({ id: `n-${d.userId}`, ...d }))),
        ),
      },
    };
    const prisma = {
      $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    };
    return { prisma, tx };
  }

  it('nhắc đội trưởng/phó cả hai đội, tên đối thủ theo từng đội', async () => {
    const { prisma, tx } = setup(base);
    const rows = await promptMatchResult(prisma as never, 'm1', new Date());
    expect(rows.map((r) => r.userId)).toEqual(['mgr-h', 'mgr-a']);
    const titles = tx.notification.createManyAndReturn.mock.calls.map(
      (c) => (c[0] as { data: { title: string }[] }).data[0].title,
    );
    expect(titles).toEqual([
      'Trận gặp FC Khách đã kết thúc',
      'Trận gặp FC Nhà đã kết thúc',
    ]);
  });

  it('bỏ qua: đã nhập tỉ số, trận huỷ, chưa tới giờ, không tồn tại', async () => {
    for (const m of [
      { ...base, homeScore: 2 },
      { ...base, status: 'cancelled' },
      { ...base, endAt: new Date(Date.now() + 3_600_000) },
      null,
    ]) {
      const { prisma, tx } = setup(m);
      expect(
        await promptMatchResult(prisma as never, 'm1', new Date()),
      ).toEqual([]);
      expect(tx.notification.createManyAndReturn).not.toHaveBeenCalled();
    }
  });
});
