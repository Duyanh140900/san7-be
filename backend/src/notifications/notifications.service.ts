import { InjectQueue } from '@nestjs/bullmq';
import { Injectable, Logger } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type { NotificationRow } from './notification-writer.js';
import type {
  ListNotificationsQuery,
  NotificationDto,
  NotificationPageDto,
  NotificationPayloadDto,
} from './notifications.dto.js';

export function toNotificationDto(n: NotificationRow): NotificationDto {
  return {
    id: n.id,
    type: n.type,
    category: n.category,
    title: n.title,
    body: n.body,
    payload: (n.payload ?? {}) as NotificationPayloadDto,
    read: n.readAt !== null,
    createdAt: n.createdAt,
  };
}

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
  ) {}

  /** Gửi thông báo vừa commit: realtime tới app đang mở + đưa job push vào hàng đợi. */
  async dispatch(rows: NotificationRow[]): Promise<void> {
    if (rows.length === 0) return;
    for (const n of rows) {
      this.realtime.toUser(n.userId, 'notification.new', toNotificationDto(n));
    }
    try {
      await this.queue.add(
        Jobs.pushSend,
        { notificationIds: rows.map((n) => n.id) },
        {
          attempts: 3,
          backoff: { type: 'exponential', delay: 5_000 },
          removeOnComplete: true,
          removeOnFail: 100,
        },
      );
    } catch (e) {
      // Push hỏng không làm hỏng thao tác chính; thông báo vẫn có trong app
      this.logger.warn(`Không đưa được job push: ${String(e)}`);
    }
  }

  async list(
    userId: string,
    q: ListNotificationsQuery,
  ): Promise<NotificationPageDto> {
    const limit = q.limit ?? 30;
    const [rows, unreadCount] = await Promise.all([
      this.prisma.notification.findMany({
        where: { userId, ...(q.category ? { category: q.category } : {}) },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
        ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
      }),
      this.unreadCount(userId),
    ]);
    const page = rows.slice(0, limit);
    return {
      items: page.map(toNotificationDto),
      nextCursor: rows.length > limit ? page[page.length - 1].id : undefined,
      unreadCount,
    };
  }

  unreadCount(userId: string): Promise<number> {
    return this.prisma.notification.count({ where: { userId, readAt: null } });
  }

  async markRead(userId: string, ids?: string[]): Promise<void> {
    await this.prisma.notification.updateMany({
      where: { userId, readAt: null, ...(ids ? { id: { in: ids } } : {}) },
      data: { readAt: new Date() },
    });
  }
}
