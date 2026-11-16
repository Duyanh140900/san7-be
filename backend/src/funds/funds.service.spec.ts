import type { TeamMembership } from '../common/team-member.guard.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { balanceEffect, FundsService, vnMonth } from './funds.service.js';

const me: TeamMembership = { teamId: 't1', userId: 'cap', role: 'captain' };

function setup() {
  let n = 0;
  const tx = {
    teamMember: { count: vi.fn() },
    event: { count: vi.fn().mockResolvedValue(1) },
    fundTransaction: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn((_args: { data: Record<string, unknown> }) =>
        Promise.resolve({ id: `tx${++n}` }),
      ),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      findUniqueOrThrow: vi.fn(),
      findFirst: vi.fn(),
      delete: vi.fn(),
    },
    team: { update: vi.fn() },
    $queryRaw: vi.fn().mockResolvedValue([]),
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    fundTransaction: { findMany: vi.fn().mockResolvedValue([]) },
  };
  const realtime = { toTeam: vi.fn() };
  const service = new FundsService(
    prisma as unknown as PrismaService,
    realtime as unknown as RealtimeService,
  );
  return { service, tx, prisma, realtime };
}

describe('vnMonth', () => {
  it('đầu tháng theo giờ Việt Nam (UTC+7)', () => {
    // 2026-11-30 18:00 UTC = 2026-12-01 01:00 giờ VN → đã sang tháng 12
    const r = vnMonth(new Date('2026-11-30T18:00:00Z'));
    expect(r.period).toBe('2026-12');
    expect(r.start.toISOString()).toBe('2026-11-30T17:00:00.000Z');
  });
});

describe('balanceEffect', () => {
  it('thu +, chi −, phạt chỉ tính khi đã nộp', () => {
    expect(balanceEffect('income', 100n, true)).toBe(100n);
    expect(balanceEffect('expense', 100n, true)).toBe(-100n);
    expect(balanceEffect('fine', 100n, false)).toBe(0n);
    expect(balanceEffect('fine', 100n, true)).toBe(100n);
  });
});

describe('FundsService.create', () => {
  it('thu từ nhiều người: mỗi người một dòng cùng batchId, số dư cộng tổng', async () => {
    const { service, tx, realtime } = setup();
    tx.teamMember.count.mockResolvedValue(2);
    await service.create(me, {
      type: 'income',
      amount: 200_000,
      category: 'Quỹ tháng 11',
      memberIds: ['a', 'b', 'a'],
      period: '2026-11',
    });
    expect(tx.fundTransaction.create).toHaveBeenCalledTimes(2);
    const rows = tx.fundTransaction.create.mock.calls.map(
      (c: unknown[]) => (c[0] as { data: Record<string, unknown> }).data,
    );
    expect(rows[0].batchId).toBeTruthy();
    expect(rows[0].batchId).toBe(rows[1].batchId);
    expect(rows.map((r) => r.memberId)).toEqual(['a', 'b']);
    expect(tx.team.update).toHaveBeenCalledWith({
      where: { id: 't1' },
      data: { fundBalance: { increment: 400_000n } },
    });
    expect(realtime.toTeam).toHaveBeenCalledWith('t1', 'funds.changed', {});
  });

  it('chi: trừ số dư', async () => {
    const { service, tx } = setup();
    tx.teamMember.count.mockResolvedValue(1);
    await service.create(me, {
      type: 'expense',
      amount: 300_000,
      category: 'Tiền sân',
      memberIds: ['a'],
    });
    expect(tx.team.update).toHaveBeenCalledWith({
      where: { id: 't1' },
      data: { fundBalance: { increment: -300_000n } },
    });
  });

  it('phạt chưa nộp: không đổi số dư', async () => {
    const { service, tx } = setup();
    tx.teamMember.count.mockResolvedValue(1);
    await service.create(me, {
      type: 'fine',
      amount: 50_000,
      category: 'Đi muộn',
      memberIds: ['a'],
    });
    expect(tx.fundTransaction.create.mock.calls[0][0].data.paid).toBe(false);
    expect(tx.team.update).not.toHaveBeenCalled();
  });

  it('phạt không chọn người, chi nhiều người → 400', async () => {
    const { service } = setup();
    await expect(
      service.create(me, { type: 'fine', amount: 1, category: 'x' }),
    ).rejects.toMatchObject({ status: 400 });
    await expect(
      service.create(me, {
        type: 'expense',
        amount: 1,
        category: 'x',
        memberIds: ['a', 'b'],
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('người không thuộc đội → 400, không ghi gì', async () => {
    const { service, tx } = setup();
    tx.teamMember.count.mockResolvedValue(1);
    await expect(
      service.create(me, {
        type: 'income',
        amount: 1,
        category: 'x',
        memberIds: ['a', 'stranger'],
      }),
    ).rejects.toMatchObject({ status: 400 });
    expect(tx.fundTransaction.create).not.toHaveBeenCalled();
  });

  it('đóng quỹ tháng hai lần cùng kỳ → 409', async () => {
    const { service, tx } = setup();
    tx.teamMember.count.mockResolvedValue(1);
    tx.fundTransaction.findMany.mockResolvedValueOnce([
      { member: { name: 'Văn Nam' } },
    ]);
    await expect(
      service.create(me, {
        type: 'income',
        amount: 200_000,
        category: 'Quỹ tháng 11',
        memberIds: ['a'],
        period: '2026-11',
      }),
    ).rejects.toMatchObject({ status: 409 });
    expect(tx.fundTransaction.create).not.toHaveBeenCalled();
  });
});

describe('FundsService phạt và xoá', () => {
  it('đánh dấu đã nộp phạt → cộng số dư', async () => {
    const { service, tx } = setup();
    tx.fundTransaction.findUniqueOrThrow.mockResolvedValue({
      id: 'f1',
      type: 'fine',
      amount: 50_000n,
      category: 'Đi muộn',
      period: null,
      note: null,
      paid: true,
      createdAt: new Date(),
      member: null,
      event: null,
      createdBy: { id: 'cap', name: 'Cap', avatarUrl: null },
    });
    await service.markFinePaid(me, 'f1');
    expect(tx.team.update).toHaveBeenCalledWith({
      where: { id: 't1' },
      data: { fundBalance: { increment: 50_000n } },
    });
  });

  it('phạt đã nộp rồi hoặc không tồn tại → 404', async () => {
    const { service, tx } = setup();
    tx.fundTransaction.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.markFinePaid(me, 'f1')).rejects.toMatchObject({
      status: 404,
    });
    expect(tx.team.update).not.toHaveBeenCalled();
  });

  it('xoá khoản chi → hoàn lại số dư', async () => {
    const { service, tx } = setup();
    tx.fundTransaction.findFirst.mockResolvedValue({
      id: 'e1',
      type: 'expense',
      amount: 300_000n,
      paid: true,
    });
    await service.remove(me, 'e1');
    expect(tx.team.update).toHaveBeenCalledWith({
      where: { id: 't1' },
      data: { fundBalance: { decrement: -300_000n } },
    });
  });
});

describe('FinesQuery', () => {
  it('nhận tháng YYYY-MM, từ chối định dạng sai (regex không mất ký tự thoát)', async () => {
    const { plainToInstance } = await import('class-transformer');
    const { validate } = await import('class-validator');
    const { FinesQuery } = await import('./funds.dto.js');
    for (const [period, ok] of [
      ['2026-11', true],
      ['2020-01', true],
      ['2026-1', false],
      ['abcd-ef', false],
      [undefined, true],
    ] as const) {
      const errors = await validate(plainToInstance(FinesQuery, { period }));
      expect(errors.length === 0).toBe(ok);
    }
  });
});

describe('FundsService.fines', () => {
  const row = (id: string, amount: bigint, paid: boolean) => ({
    id,
    type: 'fine',
    amount,
    category: 'Đi muộn',
    period: null,
    note: null,
    paid,
    createdAt: new Date('2026-11-13T03:00:00Z'),
    member: { id: 'u1', name: 'Minh Tú', avatarUrl: null },
    event: null,
    createdBy: { id: 'c', name: 'Đội trưởng', avatarUrl: null },
  });

  it('tổng phạt tháng, phần chưa nộp, chỉ khoản phạt trong tháng (giờ VN)', async () => {
    const { service, prisma } = setup();
    prisma.fundTransaction.findMany.mockResolvedValue([
      row('a', 50_000n, true),
      row('b', 100_000n, false),
      row('c', 50_000n, false),
    ]);
    const r = await service.fines(me, { period: '2026-11' });
    expect(r).toMatchObject({
      period: '2026-11',
      total: 200_000,
      unpaid: 150_000,
    });
    expect(r.items).toHaveLength(3);
    const where = prisma.fundTransaction.findMany.mock.calls[0][0].where;
    expect(where).toMatchObject({ teamId: 't1', type: 'fine' });
    expect(where.createdAt.gte.toISOString()).toBe('2026-10-31T17:00:00.000Z');
    expect(where.createdAt.lt.toISOString()).toBe('2026-11-30T17:00:00.000Z');
  });

  it('tháng sai định dạng → 400', async () => {
    const { service } = setup();
    await expect(
      service.fines(me, { period: '2026-13' }),
    ).rejects.toMatchObject({
      status: 400,
    });
  });
});
