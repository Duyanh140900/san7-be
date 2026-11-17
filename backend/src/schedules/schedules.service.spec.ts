import type { Queue } from 'bullmq';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { CreatePostScheduleDto } from './schedules.dto.js';
import { PostSchedulesService, postScheduleJobId, publishPostSchedule } from './schedules.service.js';

const now = new Date('2026-11-16T10:00:00.000Z');
const me: TeamMembership = { teamId: 't1', userId: 'u1', role: 'captain' };
const post = {
  type: 'find_opponent' as unknown as CreatePostScheduleDto['type'], startAt: new Date('2026-11-18T19:00:00.000Z'), endAt: new Date('2026-11-18T20:30:00.000Z'),
  level: 'tb', deal: 'friendly', scheduledAt: new Date('2026-11-17T10:00:00.000Z'), repeatWeekly: false,
};

function setup() {
  const prisma = { postSchedule: { create: vi.fn(), findFirst: vi.fn(), findMany: vi.fn(), update: vi.fn(), findUnique: vi.fn() }, $transaction: vi.fn() };
  const queue = { add: vi.fn().mockResolvedValue({}), remove: vi.fn().mockResolvedValue(undefined) };
  const media = { assertUsablePostMedia: vi.fn().mockResolvedValue(undefined) };
  return { service: new PostSchedulesService(prisma as unknown as PrismaService, queue as unknown as Queue, media as never), prisma, queue, media };
}

describe('PostSchedulesService', () => {
  it('tạo lịch một lần, lưu payload ISO và đưa job BullMQ trễ đúng giờ', async () => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    const { service, prisma, queue } = setup();
    prisma.postSchedule.create.mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, scheduledAt: post.scheduledAt, repeatWeekly: false, status: 'scheduled', publishedPostId: null });
    await service.create(me, post);
    expect(prisma.postSchedule.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ teamId: 't1', authorId: 'u1', repeatWeekly: false }) }));
    expect(queue.add).toHaveBeenCalledWith('post-schedule.publish', { scheduleId: 's1' }, expect.objectContaining({ jobId: postScheduleJobId('s1', post.scheduledAt), delay: 86_400_000 }));
    vi.useRealTimers();
  });

  it('cập nhật và hủy chỉ lịch của đội hiện tại', async () => {
    const { service, prisma, queue } = setup();
    prisma.postSchedule.findFirst.mockResolvedValue({ id: 's1', teamId: 't1', scheduledAt: post.scheduledAt, status: 'scheduled' });
    prisma.postSchedule.update.mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, scheduledAt: post.scheduledAt, repeatWeekly: false, status: 'scheduled', publishedPostId: null });
    await service.cancel(me, 's1');
    expect(prisma.postSchedule.update).toHaveBeenCalledWith({ where: { id: 's1' }, data: { status: 'cancelled' } });
    expect(queue.remove).toHaveBeenCalledWith(postScheduleJobId('s1', post.scheduledAt));
  });

  it('liệt kê lịch của đúng đội theo thời điểm đăng', async () => {
    const { service, prisma } = setup();
    prisma.postSchedule.findMany.mockResolvedValue([]);
    await expect(service.list(me)).resolves.toEqual([]);
    expect(prisma.postSchedule.findMany).toHaveBeenCalledWith({ where: { teamId: 't1' }, orderBy: { scheduledAt: 'asc' } });
  });
});

describe('publishPostSchedule', () => {
  it('lịch tuần công bố kèo rồi dời lịch và giờ đá bảy ngày', async () => {
    const tx = { postSchedule: { updateMany: vi.fn().mockResolvedValue({ count: 1 }), findUniqueOrThrow: vi.fn().mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', scheduledAt: now, status: 'scheduled', repeatWeekly: true, payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, publishedPostId: null }), update: vi.fn() }, teamMember: { findFirst: vi.fn().mockResolvedValue({ userId: 'u1' }) }, team: { findUniqueOrThrow: vi.fn().mockResolvedValue({ area: 'Cầu Giấy' }) }, post: { create: vi.fn().mockResolvedValue({ id: 'p1' }) } };
    const prisma = { $transaction: vi.fn((fn: (db: typeof tx) => unknown) => fn(tx)) };
    const result = await publishPostSchedule(prisma as unknown as PrismaService, 's1', now);
    expect(result).toMatchObject({ published: true, nextAt: new Date(now.getTime() + 7 * 86_400_000) });
    expect(tx.post.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ teamId: 't1', authorId: 'u1', area: 'Cầu Giấy' }) }));
    expect(tx.postSchedule.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ scheduledAt: new Date(now.getTime() + 7 * 86_400_000) }) }));
  });

  it('claim nguyên tử khiến worker thứ hai không tạo post trùng', async () => {
    const tx = { postSchedule: { updateMany: vi.fn().mockResolvedValue({ count: 0 }) } };
    const prisma = { $transaction: vi.fn((fn: (db: typeof tx) => unknown) => fn(tx)) };
    await expect(publishPostSchedule(prisma as unknown as PrismaService, 's1', now)).resolves.toEqual({ published: false, nextAt: null });
  });

  it('không đăng lịch khi tác giả không còn là captain hoặc vice', async () => {
    const tx = {
      postSchedule: {
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: vi.fn().mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', scheduledAt: now, status: 'scheduled', repeatWeekly: false, payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() } }),
      },
      teamMember: { findFirst: vi.fn().mockResolvedValue(null) },
      post: { create: vi.fn() },
    };
    const prisma = { $transaction: vi.fn((fn: (db: typeof tx) => unknown) => fn(tx)) };
    await expect(publishPostSchedule(prisma as unknown as PrismaService, 's1', now)).resolves.toEqual({ published: false, nextAt: null });
    expect(tx.post.create).not.toHaveBeenCalled();
  });

  it('lịch tuần bị chạy trễ bỏ kỳ cũ và dời đến giờ đá tương lai', async () => {
    const latePost = {
      ...post,
      startAt: new Date(now.getTime() - 8 * 86_400_000),
      endAt: new Date(now.getTime() - 8 * 86_400_000 + 90 * 60_000),
    };
    const schedule = { id: 's1', teamId: 't1', authorId: 'u1', scheduledAt: new Date(now.getTime() - 8 * 86_400_000), status: 'scheduled', repeatWeekly: true, payload: { ...latePost, startAt: latePost.startAt.toISOString(), endAt: latePost.endAt.toISOString() } };
    const tx = { postSchedule: { updateMany: vi.fn().mockResolvedValue({ count: 1 }), findUniqueOrThrow: vi.fn().mockResolvedValue(schedule), update: vi.fn() }, teamMember: { findFirst: vi.fn().mockResolvedValue({ userId: 'u1' }) }, post: { create: vi.fn() } };
    const prisma = { $transaction: vi.fn((fn: (db: typeof tx) => unknown) => fn(tx)) };
    const result = await publishPostSchedule(prisma as unknown as PrismaService, 's1', now);
    expect(result.nextAt).toEqual(new Date(schedule.scheduledAt.getTime() + 2 * 7 * 86_400_000));
    expect(tx.post.create).not.toHaveBeenCalled();
    expect(tx.postSchedule.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'scheduled' }) }));
  });
});
