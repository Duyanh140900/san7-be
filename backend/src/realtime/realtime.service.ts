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

  /** Đưa mọi socket của user ra khỏi room đội (bị mời ra / rời đội). */
  evictFromTeam(userId: string, teamId: string) {
    this.server?.in(`user:${userId}`).socketsLeave(`team:${teamId}`);
  }

  toUser(userId: string, event: string, payload: object) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }
}
