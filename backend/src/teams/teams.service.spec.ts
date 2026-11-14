import { Prisma } from '../generated/prisma/client.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { TeamsService } from './teams.service.js';

const future = () => new Date(Date.now() + 86_400_000);

function setup() {
  const tx = {
    team: {
      create: vi.fn((args: { data: Record<string, unknown> }) =>
        Promise.resolve({ id: 't1', ...args.data }),
      ),
    },
    teamMember: { create: vi.fn().mockResolvedValue({}) },
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    team: { findUnique: vi.fn(), findUniqueOrThrow: vi.fn(), update: vi.fn() },
    teamMember: {
      findUnique: vi.fn(),
      create: vi.fn((args: { data: Record<string, unknown> }) =>
        Promise.resolve(args.data),
      ),
      count: vi.fn().mockResolvedValue(12),
    },
  };
  return {
    service: new TeamsService(prisma as unknown as PrismaService),
    prisma,
    tx,
  };
}

describe('TeamsService', () => {
  it('tạo đội: người tạo là đội trưởng active, có mã mời', async () => {
    const { service, tx } = setup();
    const team = await service.create('u1', {
      name: ' FC Cầu Giấy ',
      area: 'Cầu Giấy',
      level: 'tb',
    });
    expect(team.name).toBe('FC Cầu Giấy');
    expect(team.inviteCode).toMatch(/^[A-Z0-9]{3}-\d{4}$/);
    expect(team.crestColor).toMatch(/^#[0-9A-F]{6}$/);
    expect(tx.teamMember.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'u1',
        role: 'captain',
        status: 'active',
      }),
    });
  });

  it('vào đội bằng mã: tạo yêu cầu pending, chấp nhận mã gõ thường', async () => {
    const { service, prisma } = setup();
    prisma.team.findUnique.mockResolvedValue({
      id: 't1',
      name: 'FC CG',
      inviteExpiresAt: future(),
    });
    prisma.teamMember.findUnique.mockResolvedValue(null);
    const m = await service.join('u2', 'cg7 2486');
    expect(prisma.team.findUnique).toHaveBeenCalledWith({
      where: { inviteCode: 'CG7-2486' },
    });
    expect(m).toEqual({
      teamId: 't1',
      teamName: 'FC CG',
      role: 'member',
      status: 'pending',
    });
  });

  it('mã sai định dạng hoặc không tồn tại → 404', async () => {
    const { service, prisma } = setup();
    await expect(service.join('u2', '!!')).rejects.toMatchObject({
      status: 404,
    });
    prisma.team.findUnique.mockResolvedValue(null);
    await expect(service.join('u2', 'AAA-1111')).rejects.toMatchObject({
      status: 404,
    });
  });

  it('mã hết hạn → 410', async () => {
    const { service, prisma } = setup();
    prisma.team.findUnique.mockResolvedValue({
      id: 't1',
      inviteExpiresAt: new Date(Date.now() - 1),
    });
    await expect(service.previewInvite('AAA-1111')).rejects.toMatchObject({
      status: 410,
    });
  });

  it('bấm vào đội hai lần cùng lúc (trùng khoá) → 409 chờ duyệt, không phải 500', async () => {
    const { service, prisma } = setup();
    prisma.team.findUnique.mockResolvedValue({
      id: 't1',
      name: 'FC',
      inviteExpiresAt: null,
    });
    prisma.teamMember.findUnique.mockResolvedValue(null);
    prisma.teamMember.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('dup', {
        code: 'P2002',
        clientVersion: 'test',
        meta: { target: ['team_id', 'user_id'] },
      }),
    );
    await expect(service.join('u2', 'AAA-1111')).rejects.toMatchObject({
      status: 409,
      response: { code: 'join_pending' },
    });
  });

  it('đã là thành viên hoặc đang chờ → 409', async () => {
    const { service, prisma } = setup();
    prisma.team.findUnique.mockResolvedValue({
      id: 't1',
      inviteExpiresAt: null,
    });
    prisma.teamMember.findUnique.mockResolvedValue({ status: 'pending' });
    await expect(service.join('u2', 'AAA-1111')).rejects.toMatchObject({
      status: 409,
    });
  });

  it('xem trước mã mời trả số thành viên active', async () => {
    const { service, prisma } = setup();
    prisma.team.findUnique.mockResolvedValue({
      id: 't1',
      name: 'FC CG',
      crestColor: '#0066CC',
      area: 'Cầu Giấy',
      level: 'tb',
      inviteExpiresAt: null,
    });
    const p = await service.previewInvite('AAA-1111');
    expect(p.memberCount).toBe(12);
    expect(prisma.teamMember.count).toHaveBeenCalledWith({
      where: { teamId: 't1', status: 'active' },
    });
  });

  const teamRow = {
    id: 't1',
    name: 'FC CG',
    crestColor: '#0066CC',
    area: 'Cầu Giấy',
    level: 'tb',
    createdAt: new Date(),
    monthlyDue: 200_000n,
    inviteCode: 'CG7-2486',
    inviteExpiresAt: null,
  };

  it('chi tiết đội: chỉ đội trưởng/phó đội thấy mã mời, tiền đổi sang số', async () => {
    const { service, prisma } = setup();
    prisma.team.findUniqueOrThrow.mockResolvedValue(teamRow);
    const asVice = await service.detail({
      teamId: 't1',
      userId: 'v',
      role: 'vice',
    });
    expect(asVice.inviteCode).toBe('CG7-2486');
    expect(asVice.monthlyDue).toBe(200_000);
    expect(asVice.memberCount).toBe(12);
    const asMember = await service.detail({
      teamId: 't1',
      userId: 'm',
      role: 'member',
    });
    expect(asMember.inviteCode).toBeUndefined();
    expect(asMember.myRole).toBe('member');
  });

  it('tạo mã mời mới: đổi mã và hạn 7 ngày', async () => {
    const { service, prisma } = setup();
    prisma.team.update.mockImplementation(
      (args: { data: { inviteCode: string; inviteExpiresAt: Date } }) =>
        Promise.resolve({ ...teamRow, ...args.data }),
    );
    const r = await service.regenerateInvite({
      teamId: 't1',
      userId: 'c',
      role: 'captain',
    });
    expect(r.inviteCode).toMatch(/^[A-Z0-9]{3}-\d{4}$/);
    const days = (r.inviteExpiresAt.getTime() - Date.now()) / 86_400_000;
    expect(days).toBeGreaterThan(6.9);
    expect(days).toBeLessThan(7.1);
  });
});
