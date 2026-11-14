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
    team: { findUnique: vi.fn() },
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
});
