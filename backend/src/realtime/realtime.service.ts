import { Injectable } from '@nestjs/common';
import type { Server } from 'socket.io';

/** Sự kiện realtime gửi về app. Tên dạng "<miền>.<hành động>". */
export type TeamEvent =
  'attendance.updated' | 'events.changed' | 'funds.changed' | 'members.changed';

export type PostEvent =
  'comment.created' | 'comment.deleted' | 'reaction.changed';

export type MatchEvent = 'chat.message';

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

  toPost(postId: string, event: PostEvent, payload: Record<string, unknown>) {
    this.server?.to(`post:${postId}`).emit(event, { postId, ...payload });
  }

  toMatch(
    matchId: string,
    event: MatchEvent,
    payload: Record<string, unknown>,
  ) {
    this.server?.to(`match:${matchId}`).emit(event, { matchId, ...payload });
  }

  /** Đưa mọi socket của user ra khỏi room đội (bị mời ra / rời đội). */
  evictFromTeam(userId: string, teamId: string) {
    const sockets = this.server?.in(`user:${userId}`);
    sockets?.socketsLeave(`team:${teamId}`);
    // Một socket có thể đã vào room match của đội. Ngắt kết nối để client phải
    // xác thực và join lại với membership hiện tại, thay vì tiếp tục nhận chat.
    sockets?.disconnectSockets(true);
  }

  toUser(userId: string, event: string, payload: object) {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }
}
