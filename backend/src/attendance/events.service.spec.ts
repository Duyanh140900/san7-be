import type { TeamMembership } from '../common/team-member.guard.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { countAttendance, EventsService } from './events.service.js';

const me: TeamMembership = { teamId: 't1', userId: 'u1', role: 'member' };

function setup() {
  const prisma = {
    event: {
      findFirst: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
    attendance: { upsert: vi.fn(), findMany: vi.fn() },
    teamMember: { findMany: vi.fn() },
  };
  const realtime = { toTeam: vi.fn() };
  const service = new EventsService(
    prisma as unknown as PrismaService,
    realtime as unknown as RealtimeService,
  );
  return { service, prisma, realtime };
}

describe('countAttendance', () => {
  it('chỉ đếm người còn trong đội, phần còn lại là chưa trả lời', () => {
    const active = new Set(['a', 'b', 'c', 'd']);
    const c = countAttendance(active, [
      { userId: 'a', status: 'go' },
      { userId: 'b', status: 'maybe' },
      { userId: 'left', status: 'go' },
    ]);
    expect(c).toEqual({ go: 1, maybe: 1, no: 0, pending: 2 });
  });
});

describe('EventsService.setAttendance', () => {
  it('lưu điểm danh và phát realtime kèm số đếm mới', async () => {
    const { service, prisma, realtime } = setup();
    prisma.event.findFirst.mockResolvedValue({
      id: 'e1',
      endAt: new Date(Date.now() + 3_600_000),
    });
    prisma.teamMember.findMany.mockResolvedValue([
      { userId: 'u1' },
      { userId: 'u2' },
    ]);
    prisma.attendance.findMany.mockResolvedValue([
      { userId: 'u1', status: 'go' },
    ]);
    const counts = await service.setAttendance(me, 'e1', { status: 'go' });
    expect(prisma.attendance.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { eventId_userId: { eventId: 'e1', userId: 'u1' } },
      }),
    );
    expect(counts).toEqual({ go: 1, maybe: 0, no: 0, pending: 1 });
    expect(realtime.toTeam).toHaveBeenCalledWith(
      't1',
      'attendance.updated',
      expect.objectContaining({
        eventId: 'e1',
        userId: 'u1',
        status: 'go',
        counts,
      }),
    );
  });

  it('lịch đã kết thúc → 409', async () => {
    const { service, prisma } = setup();
    prisma.event.findFirst.mockResolvedValue({
      id: 'e1',
      endAt: new Date(Date.now() - 1000),
    });
    await expect(
      service.setAttendance(me, 'e1', { status: 'no' }),
    ).rejects.toMatchObject({ status: 409 });
    expect(prisma.attendance.upsert).not.toHaveBeenCalled();
  });

  it('lịch của đội khác → 404', async () => {
    const { service, prisma } = setup();
    prisma.event.findFirst.mockResolvedValue(null);
    await expect(
      service.setAttendance(me, 'e1', { status: 'go' }),
    ).rejects.toMatchObject({ status: 404 });
  });
});

describe('EventsService.create', () => {
  it('giờ kết thúc trước giờ bắt đầu → 400', async () => {
    const { service, prisma } = setup();
    const start = new Date('2026-11-22T12:00:00Z');
    await expect(
      service.create(
        { ...me, role: 'captain' },
        {
          kind: 'match',
          title: 'vs Mỹ Đình',
          startAt: start,
          endAt: new Date(start.getTime() - 60_000),
        },
      ),
    ).rejects.toMatchObject({ status: 400 });
    expect(prisma.event.create).not.toHaveBeenCalled();
  });
});

describe('lịch sinh từ đặt sân', () => {
  const captain: TeamMembership = { ...me, role: 'captain' };
  const booked = {
    id: 'e1',
    bookingId: 'b1',
    startAt: new Date('2026-11-22T12:00:00Z'),
    endAt: new Date('2026-11-22T13:30:00Z'),
  };

  it('không xoá được (phải huỷ đặt sân)', async () => {
    const { service, prisma } = setup();
    prisma.event.findFirst.mockResolvedValue(booked);
    await expect(service.remove(captain, 'e1')).rejects.toMatchObject({
      status: 409,
      response: { code: 'event_has_booking' },
    });
    expect(prisma.event.delete).not.toHaveBeenCalled();
  });

  it('không đổi giờ/địa điểm được nhưng sửa ghi chú thì được', async () => {
    const { service, prisma } = setup();
    prisma.event.findFirst.mockResolvedValue(booked);
    await expect(
      service.update(captain, 'e1', {
        startAt: new Date('2026-11-23T12:00:00Z'),
      }),
    ).rejects.toMatchObject({ response: { code: 'event_has_booking' } });
    await expect(
      service.update(captain, 'e1', { location: 'Sân khác' }),
    ).rejects.toMatchObject({ status: 409 });
    expect(prisma.event.update).not.toHaveBeenCalled();
  });

  it('lịch thường vẫn xoá được', async () => {
    const { service, prisma } = setup();
    prisma.event.findFirst.mockResolvedValue({ ...booked, bookingId: null });
    await service.remove(captain, 'e1');
    expect(prisma.event.delete).toHaveBeenCalledWith({ where: { id: 'e1' } });
  });
});
