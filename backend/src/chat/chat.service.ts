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
  InboxDto,
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
    const otherTeamId = member.teamId === match.homeTeamId ? match.awayTeamId : match.homeTeamId;
    const blocked = await this.prisma.teamBlock.findUnique({
      where: { blockerTeamId_blockedTeamId: { blockerTeamId: member.teamId, blockedTeamId: otherTeamId } },
      select: { blockerTeamId: true },
    });
    if (blocked) {
      throw new AppError(HttpStatus.NOT_FOUND, 'chat_not_found', 'Không tìm thấy cuộc trò chuyện');
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

  async inbox(userId: string): Promise<InboxDto> {
    const teams = await this.prisma.teamMember.findMany({
      where: { userId, status: 'active' }, select: { teamId: true },
    });
    const teamIds = teams.map((item) => item.teamId);
    if (!teamIds.length) return { items: [], unreadTotal: 0 };
    const matches = await this.prisma.match.findMany({
      where: { OR: [{ homeTeamId: { in: teamIds } }, { awayTeamId: { in: teamIds } }] },
      include: {
        homeTeam: { select: { id: true, name: true, crestColor: true } },
        awayTeam: { select: { id: true, name: true, crestColor: true } },
        messages: { include: { user: { select: senderSelect } }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: 1 },
        chatReads: { where: { userId }, select: { teamId: true, lastReadAt: true } },
      },
    });
    const items = await Promise.all(matches.map(async (match) => {
      const myTeamId = teamIds.includes(match.homeTeamId) ? match.homeTeamId : match.awayTeamId;
      const opponent = myTeamId === match.homeTeamId ? match.awayTeam : match.homeTeam;
      const readAt = match.chatReads.find((row) => row.teamId === myTeamId)?.lastReadAt;
      const unreadCount = await this.prisma.matchMessage.count({ where: { matchId: match.id, teamId: { not: myTeamId }, ...(readAt ? { createdAt: { gt: readAt } } : {}) } });
      return { matchId: match.id, teamId: opponent.id, teamName: opponent.name, crestColor: opponent.crestColor, lastMessage: match.messages[0] ? this.toDto(match.messages[0]) : null, updatedAt: match.messages[0]?.createdAt ?? match.createdAt, unreadCount };
    }));
    items.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());
    return { items, unreadTotal: items.reduce((total, item) => total + item.unreadCount, 0) };
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
