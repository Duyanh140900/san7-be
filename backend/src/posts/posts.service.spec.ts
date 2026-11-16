import { Prisma } from '../generated/prisma/client.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { CreatePostDto } from './posts.dto.js';
import type { NotificationsService } from '../notifications/notifications.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { effectiveStatus, requestExpiry } from './post-mapper.js';
import { normalizePost, PostsService } from './posts.service.js';

const HOUR = 3_600_000;
const now = new Date('2026-11-14T10:00:00Z');
const me: TeamMembership = { teamId: 't1', userId: 'u1', role: 'captain' };

const dto = (over: Partial<CreatePostDto> = {}): CreatePostDto => ({
  type: 'find_opponent',
  startAt: new Date(now.getTime() + 24 * HOUR),
  endAt: new Date(now.getTime() + 25.5 * HOUR),
  level: 'tb',
  deal: 'split',
  ratioWin: 40,
  ratioLose: 60,
  ...over,
});

describe('normalizePost', () => {
  it('tìm đối chia tiền: giữ tỷ lệ, bỏ trường tuyển người', () => {
    const d = normalizePost(
      dto({ positions: ['goalkeeper'], pitchPrice: 600_000 }),
      now,
    );
    expect(d).toMatchObject({
      deal: 'split',
      ratioWin: 40,
      ratioLose: 60,
      positions: [],
    });
    expect(d.pitchPrice).toBe(600_000n);
  });

  it('thua trả sân = 0–100; kèo nước/giao hữu không có tỷ lệ', () => {
    expect(normalizePost(dto({ deal: 'loser_pays' }), now)).toMatchObject({
      ratioWin: 0,
      ratioLose: 100,
    });
    expect(normalizePost(dto({ deal: 'friendly' }), now)).toMatchObject({
      ratioWin: null,
      ratioLose: null,
    });
  });

  it('lỗi: thiếu kèo, tỷ lệ sai, giờ quá khứ, quá dài, quá xa', () => {
    const code = (d: CreatePostDto) => {
      try {
        normalizePost(d, now);
        return null;
      } catch (e) {
        return (e as { response: { code: string } }).response.code;
      }
    };
    expect(code(dto({ deal: undefined }))).toBe('deal_required');
    expect(code(dto({ ratioWin: 50, ratioLose: 60 }))).toBe('invalid_ratio');
    expect(code(dto({ startAt: new Date(now.getTime() - HOUR) }))).toBe(
      'invalid_time',
    );
    expect(code(dto({ endAt: new Date(now.getTime() + 31 * HOUR) }))).toBe(
      'invalid_time',
    );
    expect(
      code(
        dto({
          startAt: new Date(now.getTime() + 61 * 24 * HOUR),
          endAt: new Date(now.getTime() + 61 * 24 * HOUR + HOUR),
        }),
      ),
    ).toBe('invalid_time');
  });

  it('tuyển người cần vị trí hoặc số người; pass sân cần tên sân', () => {
    expect(() =>
      normalizePost(dto({ type: 'recruit', deal: undefined }), now),
    ).toThrow();
    expect(
      normalizePost(
        dto({
          type: 'recruit',
          positions: ['goalkeeper', 'goalkeeper'],
          playersNeeded: 2,
        }),
        now,
      ),
    ).toMatchObject({
      positions: ['goalkeeper'],
      playersNeeded: 2,
      deal: null,
    });
    expect(() => normalizePost(dto({ type: 'pass_pitch' }), now)).toThrow();
    expect(
      normalizePost(dto({ type: 'pass_pitch', pitchName: 'Phúc La' }), now)
        .pitchName,
    ).toBe('Phúc La');
  });
});

describe('effectiveStatus / requestExpiry', () => {
  it('pending quá hạn = expired', () => {
    expect(effectiveStatus({ status: 'pending', expiresAt: now }, now)).toBe(
      'expired',
    );
    expect(
      effectiveStatus(
        { status: 'pending', expiresAt: new Date(now.getTime() + 1) },
        now,
      ),
    ).toBe('pending');
    expect(
      effectiveStatus({ status: 'accepted', expiresAt: new Date(0) }, now),
    ).toBe('accepted');
  });

  it('hạn = min(2 giờ, giờ đá)', () => {
    const far = new Date(now.getTime() + 10 * HOUR);
    const near = new Date(now.getTime() + HOUR);
    expect(requestExpiry(now, far).getTime()).toBe(now.getTime() + 2 * HOUR);
    expect(requestExpiry(now, near)).toEqual(near);
  });
});

function setup() {
  const tx = {
    $queryRaw: vi.fn(),
    post: { findUnique: vi.fn(), update: vi.fn() },
    matchRequest: {
      updateManyAndReturn: vi.fn().mockResolvedValue([]),
    },
    teamMember: {
      findMany: vi.fn().mockResolvedValue([{ userId: 'mgr', teamId: 'g1' }]),
    },
    notification: {
      updateMany: vi.fn(),
      createManyAndReturn: vi.fn((a: { data: unknown[] }) =>
        Promise.resolve(a.data),
      ),
    },
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    team: {
      findUniqueOrThrow: vi.fn().mockResolvedValue({ area: 'Cầu Giấy' }),
    },
    booking: { findFirst: vi.fn() },
    post: {
      create: vi.fn((a: { data: Record<string, unknown> }) =>
        Promise.resolve({
          id: 'p1',
          createdAt: now,
          status: 'open',
          team: {
            id: 't1',
            name: 'FC',
            crestColor: '#000000',
            area: 'Cầu Giấy',
            level: 'tb',
          },
          _count: { requests: 0 },
          ...a.data,
        }),
      ),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  const notifications = { dispatch: vi.fn() };
  const service = new PostsService(
    prisma as unknown as PrismaService,
    notifications as unknown as NotificationsService,
  );
  return { service, prisma, tx, notifications };
}

describe('PostsService', () => {
  it('đăng kèo: khu vực mặc định của đội, tiền trả ra số thường', async () => {
    const { service, prisma } = setup();
    const p = await service.create(
      me,
      dto({
        startAt: new Date(Date.now() + 24 * HOUR),
        endAt: new Date(Date.now() + 25 * HOUR),
        pitchPrice: 600_000,
      }),
    );
    expect(prisma.post.create.mock.calls[0][0].data).toMatchObject({
      teamId: 't1',
      authorId: 'u1',
      area: 'Cầu Giấy',
    });
    expect(p.pitchPrice).toBe(600_000);
    expect(p.requestCount).toBe(0);
  });

  it('Bảng tin: chỉ kèo mở chưa tới giờ, lọc loại + khu vực, phân trang cursor', async () => {
    const { service, prisma } = setup();
    await service.feed({
      type: 'find_opponent',
      area: 'Hà Đông',
      cursor: 'c1',
      limit: 5,
    });
    const args = prisma.post.findMany.mock.calls[0][0];
    expect(args.where).toMatchObject({
      status: 'open',
      type: 'find_opponent',
      area: 'Hà Đông',
    });
    expect(args.where.startAt.gt).toBeInstanceOf(Date);
    expect(args).toMatchObject({ take: 6, cursor: { id: 'c1' }, skip: 1 });
  });

  it('đóng kèo: từ chối yêu cầu đang chờ và báo đội gửi', async () => {
    const { service, tx, notifications } = setup();
    tx.post.findUnique.mockResolvedValue({
      id: 'p1',
      teamId: 't1',
      status: 'open',
      startAt: new Date(),
      pitchName: null,
      team: { name: 'FC' },
    });
    tx.matchRequest.updateManyAndReturn.mockResolvedValue([
      { id: 'r1', teamId: 'g1' },
    ]);
    await service.close(me, 'p1');
    expect(tx.post.update).toHaveBeenCalledWith({
      where: { id: 'p1' },
      data: { status: 'closed', bookingId: null },
    });
    expect(tx.matchRequest.updateManyAndReturn).toHaveBeenCalled();
    expect(notifications.dispatch).toHaveBeenCalledWith([
      expect.objectContaining({ userId: 'mgr', type: 'post.closed' }),
    ]);
  });

  it('đóng kèo của đội khác → 404, kèo đã chốt → 409', async () => {
    const { service, tx } = setup();
    tx.post.findUnique.mockResolvedValue({
      id: 'p1',
      teamId: 'x',
      status: 'open',
    });
    await expect(service.close(me, 'p1')).rejects.toMatchObject({
      status: 404,
    });
    tx.post.findUnique.mockResolvedValue({
      id: 'p1',
      teamId: 't1',
      status: 'matched',
    });
    await expect(service.close(me, 'p1')).rejects.toMatchObject({
      status: 409,
    });
  });
});

describe('PostsService.create với sân đã đặt', () => {
  const HOUR_MS = 3_600_000;
  const startAt = new Date(Date.now() + 30 * HOUR_MS);
  const booked = {
    id: 'b1',
    pitchId: 'pi1',
    status: 'confirmed',
    startAt,
    endAt: new Date(startAt.getTime() + 1.5 * HOUR_MS),
    pitch: { name: 'Hà Đông Arena', district: 'Hà Đông' },
  };

  it('giờ, sân, khu vực lấy theo lượt đặt; bỏ giờ client gửi', async () => {
    const { service, prisma } = setup();
    prisma.booking.findFirst.mockResolvedValue(booked);
    await service.create(
      me,
      dto({
        bookingId: 'b1',
        startAt: new Date(Date.now() + 99 * HOUR_MS),
        endAt: new Date(Date.now() + 100 * HOUR_MS),
      }),
    );
    expect(prisma.booking.findFirst).toHaveBeenCalledWith({
      where: { id: 'b1', teamId: 't1' },
      include: { pitch: { select: { name: true, district: true } } },
    });
    expect(prisma.post.create.mock.calls[0][0].data).toMatchObject({
      bookingId: 'b1',
      pitchId: 'pi1',
      pitchName: 'Hà Đông Arena',
      area: 'Hà Đông',
      startAt,
      endAt: booked.endAt,
    });
  });

  it('lượt đặt của đội khác → 404; chưa xác nhận hoặc đã qua → 400', async () => {
    const { service, prisma } = setup();
    prisma.booking.findFirst.mockResolvedValue(null);
    await expect(
      service.create(me, dto({ bookingId: 'b1' })),
    ).rejects.toMatchObject({ status: 404 });
    prisma.booking.findFirst.mockResolvedValue({ ...booked, status: 'held' });
    await expect(
      service.create(me, dto({ bookingId: 'b1' })),
    ).rejects.toMatchObject({ response: { code: 'booking_not_usable' } });
    prisma.booking.findFirst.mockResolvedValue({
      ...booked,
      startAt: new Date(Date.now() - HOUR_MS),
    });
    await expect(
      service.create(me, dto({ bookingId: 'b1' })),
    ).rejects.toMatchObject({ response: { code: 'booking_not_usable' } });
  });

  it('chỉ kèo tìm đối mới gắn sân đã đặt', async () => {
    const { service, prisma } = setup();
    await expect(
      service.create(
        me,
        dto({ type: 'recruit', playersNeeded: 2, bookingId: 'b1' }),
      ),
    ).rejects.toMatchObject({ response: { code: 'booking_not_allowed' } });
    expect(prisma.booking.findFirst).not.toHaveBeenCalled();
  });

  it('một sân chỉ đăng một kèo (trùng khoá → 409)', async () => {
    const { service, prisma } = setup();
    prisma.booking.findFirst.mockResolvedValue(booked);
    prisma.post.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('dup', {
        code: 'P2002',
        clientVersion: 'test',
        meta: { target: ['booking_id'] },
      }),
    );
    await expect(
      service.create(me, dto({ bookingId: 'b1' })),
    ).rejects.toMatchObject({
      status: 409,
      response: { code: 'booking_already_posted' },
    });
  });
});
