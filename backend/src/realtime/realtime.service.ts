import { Injectable } from '@nestjs/common';
import type { Server } from 'socket.io';

/** Sự kiện realtime gửi về app. Tên dạng "<miền>.<hành động>". */
export type TeamEvent =
  'attendance.updated' | 'events.changed' | 'funds.changed' | 'members.changed';

/** Phát sự kiện tới room. Gọi SAU khi transaction đã commit. */
@Injectable()
export class RealtimeService {
  private server?: Server;

  attach(server: Server) {
    this.server = server;
  }

  toTeam(teamId: string, event: TeamEvent, payload: Record<string, unknown>) {
    this.server?.to(`team:${teamId}`).emit(event, { teamId, ...payload });
  }

  toUser(userId: string, event: string, payload: Record<string, unknown>) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }
}
