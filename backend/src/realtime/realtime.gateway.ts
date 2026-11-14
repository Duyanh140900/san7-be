import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from './realtime.service.js';

interface SocketData {
  userId?: string;
}

/**
 * Socket.IO ở đường dẫn /v1/socket. Xác thực bằng access token (auth.token khi kết nối).
 * Room: user:{id} (tự vào), team:{id} (client gửi 'team:join', kiểm tra là thành viên active).
 */
@WebSocketGateway({ path: '/v1/socket', cors: { origin: true } })
export class RealtimeGateway implements OnGatewayInit, OnGatewayConnection {
  private readonly logger = new Logger(RealtimeGateway.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  afterInit(server: Server) {
    this.realtime.attach(server);
  }

  async handleConnection(client: Socket) {
    const token = (client.handshake.auth as { token?: unknown }).token;
    try {
      if (typeof token !== 'string') throw new Error('missing token');
      const payload = await this.jwt.verifyAsync<{ sub: string; typ?: string }>(
        token,
      );
      if (payload.typ !== 'access') throw new Error('wrong token type');
      (client.data as SocketData).userId = payload.sub;
      await client.join(`user:${payload.sub}`);
    } catch {
      client.emit('auth:error', { code: 'token_expired' });
      client.disconnect(true);
    }
  }

  @SubscribeMessage('team:join')
  async joinTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { teamId?: string },
  ): Promise<{ ok: boolean }> {
    const userId = (client.data as SocketData).userId;
    const teamId = body?.teamId;
    if (!userId || typeof teamId !== 'string') return { ok: false };
    const member = await this.prisma.teamMember
      .findUnique({
        where: { teamId_userId: { teamId, userId } },
        select: { status: true },
      })
      .catch(() => null);
    if (member?.status !== 'active') return { ok: false };
    await client.join(`team:${teamId}`);
    return { ok: true };
  }

  @SubscribeMessage('team:leave')
  async leaveTeam(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { teamId?: string },
  ): Promise<{ ok: boolean }> {
    if (typeof body?.teamId === 'string') {
      await client.leave(`team:${body.teamId}`);
    }
    return { ok: true };
  }

  handleDisconnect(client: Socket) {
    this.logger.debug?.(`socket ${client.id} ngắt kết nối`);
  }
}
