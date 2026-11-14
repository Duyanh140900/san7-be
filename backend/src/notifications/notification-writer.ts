import type { Prisma } from '../generated/prisma/client.js';
import type { NotificationCategory } from '../generated/prisma/enums.js';

/** Dữ liệu điều hướng kèm thông báo (app đọc để mở đúng màn). */
export interface NotificationPayload {
  postId?: string;
  requestId?: string;
  /** đội của người nhận mà thông báo liên quan */
  teamId?: string;
  matchId?: string;
  eventId?: string;
}

export interface NotifyInput {
  userIds: string[];
  type: string;
  category: NotificationCategory;
  title: string;
  body: string;
  payload: NotificationPayload;
}

export interface NotificationRow {
  id: string;
  userId: string;
  type: string;
  category: NotificationCategory;
  title: string;
  body: string;
  payload: Prisma.JsonValue;
  readAt: Date | null;
  createdAt: Date;
}

type Db = Pick<Prisma.TransactionClient, 'notification' | 'teamMember'>;

/** Ghi thông báo (gọi trong transaction). Gửi realtime/push SAU khi commit. */
export async function writeNotifications(
  db: Db,
  input: NotifyInput,
): Promise<NotificationRow[]> {
  const userIds = [...new Set(input.userIds)];
  if (userIds.length === 0) return [];
  return db.notification.createManyAndReturn({
    data: userIds.map((userId) => ({
      userId,
      type: input.type,
      category: input.category,
      title: input.title,
      body: input.body,
      payload: input.payload as Prisma.InputJsonObject,
    })),
  });
}

/** Đội trưởng và đội phó đang active của đội (người nhận thông báo về kèo). */
export async function teamManagerIds(
  db: Db,
  teamId: string,
  exceptUserId?: string,
): Promise<string[]> {
  const rows = await db.teamMember.findMany({
    where: {
      teamId,
      status: 'active',
      role: { in: ['captain', 'vice'] },
      ...(exceptUserId ? { userId: { not: exceptUserId } } : {}),
    },
    select: { userId: true },
  });
  return rows.map((r) => r.userId);
}
