import type { TeamMembership } from '../common/team-member.guard.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { MembersService } from './members.service.js';

const captain: TeamMembership = {
  teamId: 't1',
  userId: 'cap',
  role: 'captain',
};

function setup() {
  const tx = {
    teamMember: {
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      update: vi.fn(),
    },
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    teamMember: {
      findMany: vi.fn(),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      deleteMany: vi.fn().mockResolvedValue({ count: 1 }),
      delete: vi.fn(),
    },
  };
  const realtime = { toTeam: vi.fn() };
  const service = new MembersService(
    prisma as unknown as PrismaService,
    realtime as unknown as RealtimeService,
  );
  return { service, prisma, tx, realtime };
}

const row = (userId: string, name: string, role: string, status: string) => ({
  userId,
  role,
  status,
  joinedAt: null,
  createdAt: new Date(),
  user: { name, avatarUrl: null, position: null, shirtNumber: null },
});

describe('MembersService', () => {
  it('list: sắp theo vai trò; thành viên thường không thấy danh sách chờ duyệt', async () => {
    const { service, prisma } = setup();
    prisma.teamMember.findMany.mockResolvedValue([
      row('m', 'An', 'member', 'active'),
      row('cap', 'Bình', 'captain', 'active'),
      row('p', 'Chờ', 'member', 'pending'),
    ]);
    const asCaptain = await service.list(captain);
    expect(asCaptain.active.map((m) => m.userId)).toEqual(['cap', 'm']);
    expect(asCaptain.pending.map((m) => m.userId)).toEqual(['p']);
    const asMember = await service.list({
      ...captain,
      userId: 'm',
      role: 'member',
    });
    expect(asMember.pending).toEqual([]);
  });

  it('duyệt yêu cầu không tồn tại → 404', async () => {
    const { service, prisma } = setup();
    prisma.teamMember.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.approve(captain, 'x')).rejects.toMatchObject({
      status: 404,
    });
  });

  it('trao đội trưởng: người trao thành đội phó, trong một transaction', async () => {
    const { service, tx, realtime } = setup();
    await service.changeRole(captain, 'm', 'captain');
    expect(tx.teamMember.updateMany).toHaveBeenCalledWith({
      where: { teamId: 't1', userId: 'm', status: 'active' },
      data: { role: 'captain' },
    });
    expect(tx.teamMember.update).toHaveBeenCalledWith({
      where: { teamId_userId: { teamId: 't1', userId: 'cap' } },
      data: { role: 'vice' },
    });
    expect(realtime.toTeam).toHaveBeenCalledWith('t1', 'members.changed', {});
  });

  it('tự đổi vai trò của mình → 400', async () => {
    const { service } = setup();
    await expect(
      service.changeRole(captain, 'cap', 'member'),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('đội trưởng không rời đội được', async () => {
    const { service, prisma } = setup();
    await expect(service.leave(captain)).rejects.toMatchObject({ status: 409 });
    expect(prisma.teamMember.delete).not.toHaveBeenCalled();
  });
});
