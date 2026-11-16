import type { Queue } from 'bullmq';
import type { TeamMembership } from '../common/team-member.guard.js';
import { vnDate, vnToUtc } from '../common/vn-time.js';
import type { NotificationsService } from '../notifications/notifications.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import {
  BookingsService,
  expireHold,
  newBookingCode,
} from './bookings.service.js';

const DAY = 86_400_000;
const me: TeamMembership = { teamId: 't1', userId: 'cap', role: 'captain' };

/** Khung 19:00 giờ VN của hai ngày tới (luôn ở tương lai). */
const slotAt = (hm: string, days = 2) =>
  vnToUtc(vnDate(new Date(Date.now() + days * DAY)), hm);

const pitchRow = {
  id: 'p1',
  courtsCount: 2,
  slotMinutes: 90,
  slots: [
    { start: '19:00', price: 600000 },
    { start: '20:30', price: 650000 },
  ],
};

function booking(over: Record<string, unknown> = {}) {
  return {
    id: 'b1',
    code: 'SC-7Q2K',
    pitchId: 'p1',
    teamId: 't1',
    createdById: 'cap',
    courtNo: 1,
    startAt: slotAt('19:00'),
    endAt: new Date(slotAt('19:00').getTime() + 90 * 60_000),
    status: 'confirmed',
    price: 600000n,
    deposit: 0n,
    note: null,
    heldUntil: null,
    slotKey: 'k',
    createdAt: new Date(),
    pitch: {
      id: 'p1',
      name: 'Hà Đông Arena',
      district: 'Hà Đông',
      address: 'Văn Quán',
    },
    post: null,
    event: { id: 'e1' },
    ...over,
  };
}

function setup() {
  const tx = {
    $queryRaw: vi.fn().mockResolvedValue([]),
    booking: {
      findFirst: vi.fn().mockResolvedValue(null),
      findMany: vi.fn().mockResolvedValue([]),
      findUniqueOrThrow: vi.fn(),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      update: vi.fn(),
      create: vi.fn((a: { data: Record<string, unknown> }) =>
        Promise.resolve(booking({ ...a.data, id: 'new', event: null })),
      ),
    },
    pitch: { findUniqueOrThrow: vi.fn().mockResolvedValue(pitchRow) },
    event: {
      create: vi.fn().mockResolvedValue({ id: 'e1' }),
      deleteMany: vi.fn(),
      updateMany: vi.fn(),
    },
    teamMember: {
      findMany: vi.fn().mockResolvedValue([{ userId: 'm1' }, { userId: 'm2' }]),
    },
    notification: {
      createManyAndReturn: vi.fn(
        (a: { data: { userId: string; type: string }[] }) =>
          Promise.resolve(a.data.map((d) => ({ id: `n-${d.userId}`, ...d }))),
      ),
    },
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
    $queryRaw: vi
      .fn()
      .mockResolvedValue([{ id: 'p1', lat: 20.98, lng: 105.79 }]),
    pitch: { findUnique: vi.fn().mockResolvedValue(pitchRow) },
    booking: {
      count: vi.fn().mockResolvedValue(0),
      findFirst: vi.fn(),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  const notifications = { dispatch: vi.fn() };
  const realtime = { toTeam: vi.fn() };
  const queue = { add: vi.fn() };
  const service = new BookingsService(
    prisma as unknown as PrismaService,
    notifications as unknown as NotificationsService,
    realtime as unknown as RealtimeService,
    queue as unknown as Queue,
  );
  return { service, tx, prisma, notifications, realtime, queue };
}

const noteTypes = (tx: ReturnType<typeof setup>['tx']) =>
  tx.notification.createManyAndReturn.mock.calls.flatMap(
    (c: unknown[]) =>
      (c[0] as { data: { userId: string; type: string }[] }).data,
  );

describe('newBookingCode', () => {
  it('dạng SC-XXXX, không có ký tự dễ nhầm', () => {
    for (let i = 0; i < 50; i++) {
      expect(newBookingCode()).toMatch(/^SC-[A-HJKMNP-Z2-9]{4}$/);
    }
  });
});

describe('BookingsService.hold', () => {
  it('giữ sân số nhỏ nhất còn trống, giá theo khung, hạn 10 phút, hẹn job nhả chỗ', async () => {
    const { service, tx, queue } = setup();
    tx.booking.findMany.mockResolvedValue([{ courtNo: 1 }]); // sân 1 đã có người
    const startAt = slotAt('19:00');
    const dto = await service.hold(me, { pitchId: 'p1', startAt });

    const data = tx.booking.create.mock.calls[0][0].data;
    expect(data).toMatchObject({
      courtNo: 2,
      status: 'held',
      price: 600000n,
      teamId: 't1',
      createdById: 'cap',
    });
    expect(data.slotKey).toBe(`p1:2:${startAt.toISOString()}`);
    expect(data.code).toMatch(/^SC-/);
    const ttl = (data.heldUntil as Date).getTime() - Date.now();
    expect(ttl).toBeGreaterThan(9.9 * 60_000);
    expect(ttl).toBeLessThanOrEqual(10 * 60_000);
    expect((data.endAt as Date).getTime() - startAt.getTime()).toBe(
      90 * 60_000,
    );
    expect(tx.$queryRaw).toHaveBeenCalled(); // khoá khung giờ
    expect(queue.add).toHaveBeenCalledWith(
      'booking.expire',
      { bookingId: 'new' },
      expect.objectContaining({ jobId: 'booking-expire-new' }),
    );
    expect(dto.pitch).toMatchObject({ lat: 20.98, lng: 105.79 });
    expect(dto.price).toBe(600000);
  });

  it('nhả các lượt giữ đã hết hạn của đúng khung giờ trước khi chọn sân', async () => {
    const { service, tx } = setup();
    await service.hold(me, { pitchId: 'p1', startAt: slotAt('19:00') });
    expect(tx.booking.updateMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        pitchId: 'p1',
        status: 'held',
        heldUntil: { lte: expect.any(Date) },
      }),
      data: expect.objectContaining({ status: 'cancelled', slotKey: null }),
    });
  });

  it('khung giờ kín → 409 slot_full, không tạo lượt đặt', async () => {
    const { service, tx } = setup();
    tx.booking.findMany.mockResolvedValue([{ courtNo: 1 }, { courtNo: 2 }]);
    await expect(
      service.hold(me, { pitchId: 'p1', startAt: slotAt('19:00') }),
    ).rejects.toMatchObject({ status: 409, response: { code: 'slot_full' } });
    expect(tx.booking.create).not.toHaveBeenCalled();
  });

  it('chặn: giờ không có ở sân, đã qua, quá 30 ngày', async () => {
    const { service } = setup();
    const code = async (startAt: Date) => {
      try {
        await service.hold(me, { pitchId: 'p1', startAt });
        return null;
      } catch (e) {
        return (e as { response: { code: string } }).response.code;
      }
    };
    expect(await code(slotAt('19:30'))).toBe('invalid_slot');
    expect(await code(slotAt('19:00', -1))).toBe('invalid_slot');
    expect(await code(slotAt('19:00', 40))).toBe('invalid_slot');
  });

  it('chặn: sân không tồn tại, giữ quá 3 sân, đội đã giữ/đặt khung này', async () => {
    const { service, prisma, tx } = setup();
    const startAt = slotAt('19:00');
    prisma.pitch.findUnique.mockResolvedValueOnce(null);
    await expect(
      service.hold(me, { pitchId: 'x', startAt }),
    ).rejects.toMatchObject({
      status: 404,
    });
    prisma.booking.count.mockResolvedValueOnce(3);
    await expect(
      service.hold(me, { pitchId: 'p1', startAt }),
    ).rejects.toMatchObject({
      response: { code: 'too_many_holds' },
    });
    tx.booking.findFirst.mockResolvedValueOnce({ id: 'old' });
    await expect(
      service.hold(me, { pitchId: 'p1', startAt }),
    ).rejects.toMatchObject({
      response: { code: 'already_booked' },
    });
  });
});

describe('BookingsService.confirm', () => {
  it('xác nhận: vào lịch đội, báo các thành viên khác, làm mới realtime', async () => {
    const { service, tx, realtime, notifications } = setup();
    const held = booking({
      status: 'held',
      heldUntil: new Date(Date.now() + 5 * 60_000),
      event: null,
    });
    tx.booking.findFirst.mockResolvedValue(held);
    tx.booking.findUniqueOrThrow.mockResolvedValue(booking());
    const dto = await service.confirm(me, 'b1');

    expect(tx.booking.updateMany).toHaveBeenCalledWith({
      where: { id: 'b1', status: 'held', heldUntil: { gt: expect.any(Date) } },
      data: expect.objectContaining({ status: 'confirmed', heldUntil: null }),
    });
    expect(tx.event.create.mock.calls[0][0].data).toMatchObject({
      teamId: 't1',
      kind: 'other',
      title: 'Đá tại Hà Đông Arena',
      location: 'Hà Đông Arena, sân số 1',
      bookingId: 'b1',
    });
    expect(noteTypes(tx).map((n) => [n.userId, n.type])).toEqual([
      ['m1', 'booking.confirmed'],
      ['m2', 'booking.confirmed'],
    ]);
    expect(tx.teamMember.findMany.mock.calls[0][0].where.userId).toEqual({
      not: 'cap',
    });
    expect(realtime.toTeam).toHaveBeenCalledWith('t1', 'events.changed', {});
    expect(notifications.dispatch).toHaveBeenCalled();
    expect(dto.status).toBe('confirmed');
  });

  it('hết hạn giữ chỗ → 409 hold_expired, không tạo lịch', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(
      booking({
        status: 'held',
        heldUntil: new Date(Date.now() - 1000),
        event: null,
      }),
    );
    await expect(service.confirm(me, 'b1')).rejects.toMatchObject({
      status: 409,
      response: { code: 'hold_expired' },
    });
    expect(tx.event.create).not.toHaveBeenCalled();
  });

  it('đã xác nhận thì trả lại luôn (gọi lặp không tạo lịch thứ hai); đã huỷ thì 409', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(booking());
    expect((await service.confirm(me, 'b1')).status).toBe('confirmed');
    expect(tx.event.create).not.toHaveBeenCalled();
    tx.booking.findFirst.mockResolvedValue(booking({ status: 'cancelled' }));
    await expect(service.confirm(me, 'b1')).rejects.toMatchObject({
      response: { code: 'booking_cancelled' },
    });
  });

  it('lượt đặt của đội khác → 404', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(null);
    await expect(service.confirm(me, 'b1')).rejects.toMatchObject({
      status: 404,
    });
    expect(tx.booking.findFirst.mock.calls[0][0].where).toEqual({
      id: 'b1',
      teamId: 't1',
    });
  });
});

describe('BookingsService.cancel', () => {
  it('huỷ: nhả chỗ, xoá lịch sinh ra, báo thành viên', async () => {
    const { service, tx, realtime } = setup();
    tx.booking.findFirst.mockResolvedValue(booking());
    tx.booking.findUniqueOrThrow.mockResolvedValue(
      booking({ status: 'cancelled', event: null }),
    );
    const dto = await service.cancel(me, 'b1');
    expect(tx.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: expect.objectContaining({ status: 'cancelled', slotKey: null }),
    });
    expect(tx.event.deleteMany).toHaveBeenCalledWith({
      where: { bookingId: 'b1' },
    });
    expect(noteTypes(tx).every((n) => n.type === 'booking.cancelled')).toBe(
      true,
    );
    expect(realtime.toTeam).toHaveBeenCalledWith('t1', 'events.changed', {});
    expect(dto.status).toBe('cancelled');
  });

  it('huỷ giữ chỗ chưa xác nhận: không làm phiền thành viên', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(
      booking({
        status: 'held',
        heldUntil: new Date(Date.now() + 60_000),
        event: null,
      }),
    );
    tx.booking.findUniqueOrThrow.mockResolvedValue(
      booking({ status: 'cancelled' }),
    );
    await service.cancel(me, 'b1');
    expect(tx.notification.createManyAndReturn).not.toHaveBeenCalled();
  });

  it('đã huỷ thì thôi; gắn với kèo hoặc đã tới giờ thì 409', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(booking({ status: 'cancelled' }));
    expect((await service.cancel(me, 'b1')).status).toBe('cancelled');
    expect(tx.booking.update).not.toHaveBeenCalled();

    tx.booking.findFirst.mockResolvedValue(
      booking({ post: { id: 'p', status: 'open' } }),
    );
    await expect(service.cancel(me, 'b1')).rejects.toMatchObject({
      response: { code: 'booking_has_post' },
    });
    tx.booking.findFirst.mockResolvedValue(
      booking({ startAt: new Date(Date.now() - 1000) }),
    );
    await expect(service.cancel(me, 'b1')).rejects.toMatchObject({
      response: { code: 'booking_started' },
    });
  });
});

describe('BookingsService.reschedule', () => {
  it('đổi giờ: đổi sân/giá theo khung mới, cập nhật lịch, báo thành viên', async () => {
    const { service, tx } = setup();
    tx.booking.findFirst.mockResolvedValue(booking());
    const startAt = slotAt('20:30');
    tx.booking.findUniqueOrThrow.mockResolvedValue(booking({ startAt }));
    await service.reschedule(me, 'b1', startAt);

    expect(tx.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: expect.objectContaining({
        startAt,
        courtNo: 1,
        price: 650000n,
        slotKey: `p1:1:${startAt.toISOString()}`,
      }),
    });
    expect(tx.event.updateMany).toHaveBeenCalledWith({
      where: { bookingId: 'b1' },
      data: expect.objectContaining({
        startAt,
        location: 'Hà Đông Arena, sân số 1',
      }),
    });
    expect(noteTypes(tx).every((n) => n.type === 'booking.rescheduled')).toBe(
      true,
    );
  });

  it('chặn: chưa xác nhận, trùng khung hiện tại, khung kín, đã gắn kèo', async () => {
    const { service, tx } = setup();
    const target = slotAt('20:30');

    tx.booking.findFirst.mockResolvedValue(
      booking({ status: 'held', heldUntil: new Date(Date.now() + 60_000) }),
    );
    await expect(service.reschedule(me, 'b1', target)).rejects.toMatchObject({
      response: { code: 'not_confirmed' },
    });

    tx.booking.findFirst.mockResolvedValue(booking());
    await expect(
      service.reschedule(me, 'b1', slotAt('19:00')),
    ).rejects.toMatchObject({
      response: { code: 'same_slot' },
    });

    tx.booking.findMany.mockResolvedValue([{ courtNo: 1 }, { courtNo: 2 }]);
    await expect(service.reschedule(me, 'b1', target)).rejects.toMatchObject({
      response: { code: 'slot_full' },
    });
    expect(tx.booking.update).not.toHaveBeenCalled();

    tx.booking.findFirst.mockResolvedValue(
      booking({ post: { id: 'p', status: 'matched' } }),
    );
    await expect(service.reschedule(me, 'b1', target)).rejects.toMatchObject({
      response: { code: 'booking_has_post' },
    });
  });
});

describe('BookingsService.list', () => {
  it('sắp tới: đã xác nhận hoặc đang giữ chưa hết hạn; đã qua: chỉ lượt đã xác nhận', async () => {
    const { service, prisma } = setup();
    await service.list(me, {});
    const up = prisma.booking.findMany.mock.calls[0][0];
    expect(up.where.teamId).toBe('t1');
    expect(up.where.OR).toEqual([
      { status: 'confirmed' },
      { status: 'held', heldUntil: { gt: expect.any(Date) } },
    ]);
    expect(up.orderBy).toEqual({ startAt: 'asc' });
    await service.list(me, { scope: 'past' });
    const past = prisma.booking.findMany.mock.calls[1][0];
    expect(past.where.status).toBe('confirmed');
    expect(past.orderBy).toEqual({ startAt: 'desc' });
  });
});

describe('expireHold', () => {
  it('chỉ nhả lượt đang giữ đã quá hạn', async () => {
    const tx = {
      booking: { updateMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };
    const now = new Date();
    expect(await expireHold(tx as never, 'b1', now)).toBe(true);
    expect(tx.booking.updateMany).toHaveBeenCalledWith({
      where: { id: 'b1', status: 'held', heldUntil: { lte: now } },
      data: {
        status: 'cancelled',
        slotKey: null,
        heldUntil: null,
        cancelledAt: now,
      },
    });
    tx.booking.updateMany.mockResolvedValue({ count: 0 });
    expect(await expireHold(tx as never, 'b1', now)).toBe(false);
  });
});
