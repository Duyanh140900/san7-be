import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { MatchStatus, MemberStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type {
  CursorPageQuery,
  MessageDto,
  MessagePageDto,
  ChatReadDto,
  SendMessageDto,
} from './chat.dto.js';

const senderSelect = { id: true, name: true, avatarUrl: true } as const;

/** Chat giữa hai đội của một kèo đã chốt: chỉ thành viên active của hai đội được đọc/gửi. */
@Injectable()
export class ChatService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  /** Trả về đội (trong hai đội của trận) mà user là thành viên active; ném lỗi nếu không phải. */
  async assertParticipant(
    userId: string,
    matchId: string,
  ): Promise<{ teamId: string; status: MatchStatus }> {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      select: { homeTeamId: true, awayTeamId: true, status: true },
    });
    if (!match) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'match_not_found',
        'Không tìm thấy trận',
      );
    }
    const member = await this.prisma.teamMember.findFirst({
      where: {
        userId,
        status: MemberStatus.active,
        teamId: { in: [match.homeTeamId, match.awayTeamId] },
      },
      select: { teamId: true },
    });
    if (!member) {
      throw new AppError(
        HttpStatus.FORBIDDEN,
        'chat_forbidden',
        'Chỉ thành viên hai đội mới xem được trao đổi của trận này',
      );
    }
    return { teamId: member.teamId, status: match.status };
  }

  async send(
    userId: string,
    matchId: string,
    dto: SendMessageDto,
  ): Promise<MessageDto> {
    const { teamId, status } = await this.assertParticipant(userId, matchId);
    if (status === MatchStatus.cancelled) {
      throw new AppError(
        HttpStatus.CONFLICT,
        'match_cancelled',
        'Trận đã huỷ, không thể gửi tin nhắn',
      );
    }
    const row = await this.prisma.matchMessage.create({
      data: { matchId, teamId, userId, body: dto.body },
      include: { user: { select: senderSelect } },
    });
    const message = this.toDto(row);
    this.realtime.toMatch(matchId, 'chat.message', { message });
    return message;
  }

  async list(
    userId: string,
    matchId: string,
    q: CursorPageQuery,
  ): Promise<MessagePageDto> {
    await this.assertParticipant(userId, matchId);
    const limit = q.limit ?? 30;
    const rows = await this.prisma.matchMessage.findMany({
      where: { matchId },
      include: { user: { select: senderSelect } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, limit);
    return {
      items: page.map((row) => this.toDto(row)),
      nextCursor: rows.length > limit ? page.at(-1)?.id : undefined,
    };
  }

  async read(userId: string, matchId: string): Promise<ChatReadDto> {
    const { teamId } = await this.assertParticipant(userId, matchId);
    const lastReadAt = new Date();
    await this.prisma.matchChatRead.upsert({
      where: { matchId_teamId: { matchId, teamId } },
      create: { matchId, teamId, userId, lastReadAt },
      update: { userId, lastReadAt },
    });
    return { lastReadAt };
  }

  private toDto(row: {
    id: string;
    matchId: string;
    teamId: string;
    body: string;
    createdAt: Date;
    user: { id: string; name: string; avatarUrl: string | null };
  }): MessageDto {
    return {
      id: row.id,
      matchId: row.matchId,
      teamId: row.teamId,
      body: row.body,
      sender: row.user,
      createdAt: row.createdAt,
    };
  }
}
