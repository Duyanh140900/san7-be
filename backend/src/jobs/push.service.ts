import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Messaging } from 'firebase-admin/messaging';
import type { Env } from '../common/env.js';
import { PrismaService } from '../prisma/prisma.service.js';

/** Mã lỗi FCM nghĩa là token không còn dùng được: xoá thiết bị. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/** Đọc service account: chấp nhận JSON thô hoặc base64. */
export function parseServiceAccount(
  raw: string,
): Record<string, string> | null {
  const text = raw.trim();
  if (!text) return null;
  const json = text.startsWith('{')
    ? text
    : Buffer.from(text, 'base64').toString('utf8');
  return JSON.parse(json) as Record<string, string>;
}

/** Gửi thông báo đẩy qua Firebase Cloud Messaging. Không cấu hình thì bỏ qua. */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);
  private messaging?: Promise<Messaging | null>;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService<Env, true>,
  ) {}

  private getMessaging(): Promise<Messaging | null> {
    this.messaging ??= (async () => {
      try {
        const account = parseServiceAccount(
          this.config.get('FIREBASE_SERVICE_ACCOUNT'),
        );
        if (!account) {
          this.logger.warn(
            'Chưa cấu hình FIREBASE_SERVICE_ACCOUNT, bỏ qua push',
          );
          return null;
        }
        const { cert, initializeApp } = await import('firebase-admin/app');
        const { getMessaging } = await import('firebase-admin/messaging');
        return getMessaging(initializeApp({ credential: cert(account) }));
      } catch (e) {
        // Cấu hình sai không tự hết khi thử lại: báo một lần, tắt push tới khi khởi động lại
        this.logger.error(
          `FIREBASE_SERVICE_ACCOUNT không hợp lệ, tắt push: ${String(e)}`,
        );
        return null;
      }
    })();
    return this.messaging;
  }

  async sendNotifications(notificationIds: string[]): Promise<number> {
    const messaging = await this.getMessaging();
    if (!messaging || notificationIds.length === 0) return 0;

    const notes = await this.prisma.notification.findMany({
      where: { id: { in: notificationIds }, readAt: null },
      include: {
        user: { select: { devices: { select: { fcmToken: true } } } },
      },
    });
    const unread = await this.prisma.notification.groupBy({
      by: ['userId'],
      where: { userId: { in: notes.map((n) => n.userId) }, readAt: null },
      _count: { _all: true },
    });
    const badge = new Map(unread.map((u) => [u.userId, u._count._all]));

    let sent = 0;
    const dead: string[] = [];
    for (const n of notes) {
      const tokens = n.user.devices.map((d) => d.fcmToken);
      if (tokens.length === 0) continue;
      const payload = Object.fromEntries(
        Object.entries((n.payload ?? {}) as Record<string, unknown>)
          .filter(([, v]) => typeof v === 'string')
          .map(([k, v]) => [k, v as string]),
      );
      const res = await messaging.sendEachForMulticast({
        tokens,
        notification: { title: n.title, body: n.body },
        data: { ...payload, type: n.type, notificationId: n.id },
        android: { priority: 'high', notification: { channelId: 'default' } },
        apns: { payload: { aps: { badge: badge.get(n.userId) ?? 0 } } },
      });
      sent += res.successCount;
      res.responses.forEach((r, i) => {
        if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) {
          dead.push(tokens[i]);
        }
      });
    }
    if (dead.length) {
      await this.prisma.device.deleteMany({
        where: { fcmToken: { in: dead } },
      });
    }
    return sent;
  }
}
