import type { Queue } from 'bullmq';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { PostSchedulesService, publishPostSchedule } from './schedules.service.js';

const now = new Date('2026-11-16T10:00:00.000Z');
const me: TeamMembership = { teamId: 't1', userId: 'u1', role: 'captain' };
const post = {
  type: 'find_opponent', startAt: new Date('2026-11-18T19:00:00.000Z'), endAt: new Date('2026-11-18T20:30:00.000Z'),
  level: 'tb', deal: 'friendly', scheduledAt: new Date('2026-11-17T10:00:00.000Z'), repeatWeekly: false,
};

function setup() {
  const prisma = { postSchedule: { create: vi.fn(), findFirst: vi.fn(), update: vi.fn(), findUnique: vi.fn() }, $transaction: vi.fn() };
  const queue = { add: vi.fn().mockResolvedValue({}), remove: vi.fn().mockResolvedValue(undefined) };
  return { service: new PostSchedulesService(prisma as unknown as PrismaService, queue as unknown as Queue), prisma, queue };
}

describe('PostSchedulesService', () => {
  it('tạo lịch một lần, lưu payload ISO và đưa job BullMQ trễ đúng giờ', async () => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    const { service, prisma, queue } = setup();
    prisma.postSchedule.create.mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, scheduledAt: post.scheduledAt, repeatWeekly: false, status: 'scheduled', publishedPostId: null });
    await service.create(me, post);
    expect(prisma.postSchedule.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ teamId: 't1', authorId: 'u1', repeatWeekly: false }) }));
    expect(queue.add).toHaveBeenCalledWith('post-schedule.publish', { scheduleId: 's1' }, expect.objectContaining({ jobId: 'post-schedule:s1', delay: 86_400_000 }));
    vi.useRealTimers();
  });

  it('cập nhật và hủy chỉ lịch của đội hiện tại', async () => {
    const { service, prisma, queue } = setup();
    prisma.postSchedule.findFirst.mockResolvedValue({ id: 's1', teamId: 't1', status: 'scheduled' });
    prisma.postSchedule.update.mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, scheduledAt: post.scheduledAt, repeatWeekly: false, status: 'scheduled', publishedPostId: null });
    await service.cancel(me, 's1');
    expect(prisma.postSchedule.update).toHaveBeenCalledWith({ where: { id: 's1' }, data: { status: 'cancelled' } });
    expect(queue.remove).toHaveBeenCalledWith('post-schedule:s1');
  });
});

describe('publishPostSchedule', () => {
  it('lịch tuần công bố kèo rồi dời lịch và giờ đá bảy ngày', async () => {
    const tx = { postSchedule: { findUnique: vi.fn().mockResolvedValue({ id: 's1', teamId: 't1', authorId: 'u1', scheduledAt: now, status: 'scheduled', repeatWeekly: true, payload: { ...post, startAt: post.startAt.toISOString(), endAt: post.endAt.toISOString() }, publishedPostId: null }), update: vi.fn() }, team: { findUniqueOrThrow: vi.fn().mockResolvedValue({ area: 'Cầu Giấy' }) }, post: { create: vi.fn().mockResolvedValue({ id: 'p1' }) } };
    const prisma = { $transaction: vi.fn((fn: (db: typeof tx) => unknown) => fn(tx)) };
    const result = await publishPostSchedule(prisma as unknown as PrismaService, 's1', now);
    expect(result).toMatchObject({ published: true, nextAt: new Date(now.getTime() + 7 * 86_400_000) });
    expect(tx.post.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ teamId: 't1', authorId: 'u1', area: 'Cầu Giấy' }) }));
    expect(tx.postSchedule.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ scheduledAt: new Date(now.getTime() + 7 * 86_400_000) }) }));
  });
});
