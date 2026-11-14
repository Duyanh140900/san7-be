import type { Queue } from 'bullmq';
import { parseServiceAccount } from '../jobs/push.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { teamManagerIds, writeNotifications } from './notification-writer.js';
import { NotificationsService } from './notifications.service.js';

const row = (id: string, userId: string) => ({
  id,
  userId,
  type: 'request.received',
  category: 'match' as const,
  title: 'T',
  body: 'B',
  payload: { postId: 'p1' },
  readAt: null,
  createdAt: new Date(),
});

function setup() {
  const prisma = {
    notification: {
      findMany: vi.fn().mockResolvedValue([]),
      count: vi.fn().mockResolvedValue(3),
      updateMany: vi.fn(),
    },
  };
  const realtime = { toUser: vi.fn() };
  const queue = { add: vi.fn() };
  const service = new NotificationsService(
    prisma as unknown as PrismaService,
    realtime as unknown as RealtimeService,
    queue as unknown as Queue,
  );
  return { service, prisma, realtime, queue };
}

describe('NotificationsService', () => {
  it('dispatch: realtime tới từng người + một job push', async () => {
    const { service, realtime, queue } = setup();
    await service.dispatch([row('n1', 'u1'), row('n2', 'u2')]);
    expect(realtime.toUser).toHaveBeenCalledWith(
      'u1',
      'notification.new',
      expect.objectContaining({
        id: 'n1',
        read: false,
        payload: { postId: 'p1' },
      }),
    );
    expect(queue.add).toHaveBeenCalledWith(
      'push.send',
      { notificationIds: ['n1', 'n2'] },
      expect.anything(),
    );
  });

  it('dispatch: hàng đợi lỗi không làm hỏng thao tác', async () => {
    const { service, queue } = setup();
    queue.add.mockRejectedValue(new Error('redis down'));
    await expect(service.dispatch([row('n1', 'u1')])).resolves.toBeUndefined();
  });

  it('danh sách: lọc nhóm, trả nextCursor khi còn trang', async () => {
    const { service, prisma } = setup();
    prisma.notification.findMany.mockResolvedValue([
      row('a', 'u1'),
      row('b', 'u1'),
      row('c', 'u1'),
    ]);
    const page = await service.list('u1', { category: 'match', limit: 2 });
    expect(prisma.notification.findMany.mock.calls[0][0].where).toEqual({
      userId: 'u1',
      category: 'match',
    });
    expect(page.items.map((i) => i.id)).toEqual(['a', 'b']);
    expect(page.nextCursor).toBe('b');
    expect(page.unreadCount).toBe(3);
  });

  it('đánh dấu đã đọc: chỉ của tôi', async () => {
    const { service, prisma } = setup();
    await service.markRead('u1', ['a']);
    expect(prisma.notification.updateMany.mock.calls[0][0].where).toEqual({
      userId: 'u1',
      readAt: null,
      id: { in: ['a'] },
    });
  });
});

describe('notification-writer', () => {
  it('bỏ người nhận trùng, không ghi khi rỗng', async () => {
    const db = {
      notification: { createManyAndReturn: vi.fn().mockResolvedValue([]) },
      teamMember: { findMany: vi.fn() },
    };
    await writeNotifications(db as never, {
      userIds: ['a', 'a', 'b'],
      type: 't',
      category: 'match',
      title: 'x',
      body: 'y',
      payload: {},
    });
    expect(
      db.notification.createManyAndReturn.mock.calls[0][0].data,
    ).toHaveLength(2);
    db.notification.createManyAndReturn.mockClear();
    await writeNotifications(db as never, {
      userIds: [],
      type: 't',
      category: 'match',
      title: 'x',
      body: 'y',
      payload: {},
    });
    expect(db.notification.createManyAndReturn).not.toHaveBeenCalled();
  });

  it('người nhận là đội trưởng/phó active, trừ người thao tác', async () => {
    const db = {
      notification: { createManyAndReturn: vi.fn() },
      teamMember: { findMany: vi.fn().mockResolvedValue([{ userId: 'v' }]) },
    };
    expect(await teamManagerIds(db as never, 't1', 'c')).toEqual(['v']);
    expect(db.teamMember.findMany.mock.calls[0][0].where).toEqual({
      teamId: 't1',
      status: 'active',
      role: { in: ['captain', 'vice'] },
      userId: { not: 'c' },
    });
  });
});

describe('parseServiceAccount', () => {
  it('nhận JSON thô hoặc base64, rỗng = null', () => {
    const json = '{"project_id":"x"}';
    expect(parseServiceAccount(json)).toEqual({ project_id: 'x' });
    expect(parseServiceAccount(Buffer.from(json).toString('base64'))).toEqual({
      project_id: 'x',
    });
    expect(parseServiceAccount('  ')).toBeNull();
  });
});
