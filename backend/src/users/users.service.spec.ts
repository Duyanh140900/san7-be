import type { PrismaService } from '../prisma/prisma.service.js';
import { UsersService } from './users.service.js';

function setup() {
  const prisma = {
    user: { findUnique: vi.fn(), update: vi.fn().mockResolvedValue({}) },
    device: { upsert: vi.fn().mockResolvedValue({}) },
    matchPlayerStat: {
      aggregate: vi.fn().mockResolvedValue({ _sum: { goals: 0, assists: 0 }, _count: { _all: 0 } }),
      count: vi.fn().mockResolvedValue(0),
    },
    notificationSettings: { upsert: vi.fn() },
  };
  const media = { useAvatar: vi.fn().mockResolvedValue('http://api/v1/media/public/abc') };
  return {
    service: new UsersService(prisma as unknown as PrismaService, media as never),
    prisma,
    media,
  };
}

const baseUser = {
  id: 'u1',
  email: 'a@gmail.com',
  name: 'Anh A',
  avatarUrl: null,
  position: null,
  shirtNumber: null,
  area: null,
  memberships: [],
};

describe('UsersService', () => {
  it('getMe: chưa chọn vị trí → profileCompleted false', async () => {
    const { service, prisma } = setup();
    prisma.user.findUnique.mockResolvedValue(baseUser);
    const me = await service.getMe('u1');
    expect(me.profileCompleted).toBe(false);
    expect(me.teams).toEqual([]);
    expect(me.stats).toEqual({ goals: 0, assists: 0, mvps: 0, matches: 0 });
  });

  it('getMe: có vị trí và đội → map đủ thông tin đội', async () => {
    const { service, prisma } = setup();
    prisma.user.findUnique.mockResolvedValue({
      ...baseUser,
      position: 'forward',
      memberships: [
        {
          teamId: 't1',
          role: 'captain',
          status: 'active',
          team: {
            name: 'FC CG',
            crestColor: '#0066CC',
            area: 'Cầu Giấy',
            level: 'tb',
          },
        },
      ],
    });
    const me = await service.getMe('u1');
    expect(me.profileCompleted).toBe(true);
    expect(me.teams).toEqual([
      {
        teamId: 't1',
        name: 'FC CG',
        crestColor: '#0066CC',
        area: 'Cầu Giấy',
        level: 'tb',
        role: 'captain',
        status: 'active',
      },
    ]);
  });

  it('getMe: user không tồn tại → 404', async () => {
    const { service, prisma } = setup();
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(service.getMe('x')).rejects.toMatchObject({ status: 404 });
  });

  it('registerDevice: token đã thuộc người khác thì chuyển sang người này', async () => {
    const { service, prisma } = setup();
    await service.registerDevice('u2', {
      fcmToken: 'token-token-token',
      platform: 'android',
    });
    expect(prisma.device.upsert).toHaveBeenCalledWith({
      where: { fcmToken: 'token-token-token' },
      create: {
        userId: 'u2',
        fcmToken: 'token-token-token',
        platform: 'android',
      },
      update: { userId: 'u2', platform: 'android' },
    });
  });
});

describe('UsersService.updateMe avatar', () => {
  it('avatarKey phải qua MediaService.useAvatar rồi mới ghi avatarUrl', async () => {
    const { service, prisma, media } = setup();
    prisma.user.findUnique.mockResolvedValue({ ...baseUser, memberships: [] });
    await service.updateMe('u1', { avatarKey: 'public/x.webp' });
    expect(media.useAvatar).toHaveBeenCalledWith('u1', 'public/x.webp');
    expect(prisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ avatarUrl: 'http://api/v1/media/public/abc' }) }),
    );
  });

  it('không gửi avatarKey thì không đụng avatarUrl', async () => {
    const { service, prisma, media } = setup();
    prisma.user.findUnique.mockResolvedValue({ ...baseUser, memberships: [] });
    await service.updateMe('u1', { name: 'B' });
    expect(media.useAvatar).not.toHaveBeenCalled();
    expect(prisma.user.update.mock.calls[0]![0].data.avatarUrl).toBeUndefined();
  });
});
