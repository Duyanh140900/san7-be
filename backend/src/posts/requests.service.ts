import { InjectQueue } from '@nestjs/bullmq';
import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { Prisma } from '../generated/prisma/client.js';
import type { NotificationRow } from '../notifications/notification-writer.js';
import {
  teamManagerIds,
  writeNotifications,
} from '../notifications/notification-writer.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import {
  effectiveStatus,
  livePending,
  postInclude,
  postLine,
  requestExpiry,
  teamBriefSelect,
  toPostDto,
} from './post-mapper.js';
import type {
  AcceptResultDto,
  MatchRequestDto,
  MyRequestDto,
  RequestDetailDto,
  SendRequestDto,
} from './posts.dto.js';
import { teamStats, type TeamStats } from './team-stats.js';

type Tx = Prisma.TransactionClient;

const MANAGER_ROLES = ['captain', 'vice'];

const requestInclude = {
  team: { select: teamBriefSelect },
  post: { include: { team: { select: teamBriefSelect } } },
} as const satisfies Prisma.MatchRequestInclude;

type RequestRow = Prisma.MatchRequestGetPayload<{
  include: typeof requestInclude;
}>;

function toRequestDto(
  r: Omit<RequestRow, 'post'>,
  stats: TeamStats | undefined,
  now: Date,
): MatchRequestDto {
  return {
    id: r.id,
    postId: r.postId,
    status: effectiveStatus(r, now),
    expiresAt: r.expiresAt,
    createdAt: r.createdAt,
    peopleCount: r.peopleCount,
    ratioWin: r.ratioWin,
    ratioLose: r.ratioLose,
    message: r.message,
    team: {
      ...r.team,
      memberCount: stats?.memberCount ?? 0,
      matchesPlayed: stats?.matchesPlayed ?? 0,
      headToHead: stats?.headToHead ?? 0,
    },
  };
}

/** Khoá hàng kèo trong transaction để gửi/chấp nhận/đóng không chạy chồng nhau. */
async function lockPost(tx: Tx, postId: string) {
  await tx.$queryRaw`SELECT 1 AS locked FROM posts WHERE id = ${postId}::uuid FOR UPDATE`;
}

/**
 * Đánh dấu hết hạn một yêu cầu nếu vẫn đang chờ và đã quá hạn.
 * Dùng chung cho worker (job request.expire). Trả về thông báo cần đẩy.
 */
export async function expireRequest(
  prisma: { $transaction: <T>(fn: (tx: Tx) => Promise<T>) => Promise<T> },
  requestId: string,
  now: Date,
): Promise<NotificationRow[]> {
  return prisma.$transaction(async (tx) => {
    const r = await tx.matchRequest.findUnique({
      where: { id: requestId },
      include: { post: { include: { team: { select: { name: true } } } } },
    });
    if (!r || r.status !== 'pending' || r.expiresAt > now) return [];
    const { count } = await tx.matchRequest.updateMany({
      where: { id: requestId, status: 'pending' },
      data: { status: 'expired' },
    });
    if (count === 0) return [];
    return writeNotifications(tx, {
      userIds: await teamManagerIds(tx, r.teamId),
      type: 'request.expired',
      category: 'match',
      title: `Yêu cầu nhận kèo của ${r.post.team.name} đã hết hạn`,
      body: `${postLine(r.post)} · Đội đăng kèo chưa trả lời`,
      payload: { postId: r.postId, requestId, teamId: r.teamId },
    });
  });
}

@Injectable()
export class RequestsService {
  private readonly logger = new Logger(RequestsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
  ) {}

  /** Đội của tôi (me.teamId) gửi yêu cầu nhận kèo. */
  async send(
    me: TeamMembership,
    postId: string,
    dto: SendRequestDto,
  ): Promise<MyRequestDto> {
    const now = new Date();
    if ((dto.ratioWin === undefined) !== (dto.ratioLose === undefined)) {
      throw this.bad('invalid_ratio', 'Nhập đủ tỷ lệ cho cả hai đội');
    }
    if (
      dto.ratioWin !== undefined &&
      dto.ratioWin + (dto.ratioLose ?? 0) !== 100
    ) {
      throw this.bad('invalid_ratio', 'Tỷ lệ chia phải cộng lại bằng 100');
    }

    const { request, notes } = await this.prisma.$transaction(async (tx) => {
      await lockPost(tx, postId);
      const post = await tx.post.findUnique({
        where: { id: postId },
        include: { team: { select: { name: true } } },
      });
      if (!post) throw this.postNotFound();
      if (post.type === 'recruit') {
        throw this.bad(
          'not_requestable',
          'Kèo tuyển người không nhận theo đội',
        );
      }
      if (post.status !== 'open' || post.startAt <= now) {
        throw this.conflict('post_not_open', 'Kèo đã có đối hoặc đã đóng');
      }
      if (post.teamId === me.teamId) {
        throw this.bad('own_post', 'Không thể nhận kèo của chính đội mình');
      }
      const existing = await tx.matchRequest.findFirst({
        where: { postId, teamId: me.teamId, ...livePending(now) },
        select: { id: true },
      });
      if (existing) {
        throw this.conflict(
          'request_exists',
          'Đội bạn đã gửi yêu cầu cho kèo này, đang chờ xác nhận',
        );
      }
      // Đề xuất trùng tỷ lệ của kèo = đồng ý, không lưu
      const sameRatio =
        dto.ratioWin === post.ratioWin && dto.ratioLose === post.ratioLose;
      const created = await tx.matchRequest.create({
        data: {
          postId,
          teamId: me.teamId,
          createdById: me.userId,
          peopleCount: dto.peopleCount,
          ratioWin: sameRatio ? null : (dto.ratioWin ?? null),
          ratioLose: sameRatio ? null : (dto.ratioLose ?? null),
          message: dto.message || null,
          expiresAt: requestExpiry(now, post.startAt),
        },
        include: { team: { select: { name: true } } },
      });
      const rows = await writeNotifications(tx, {
        userIds: await teamManagerIds(tx, post.teamId),
        type: 'request.received',
        category: 'match',
        title: `${created.team.name} muốn nhận kèo của đội bạn`,
        body: postLine(post),
        payload: { postId, requestId: created.id, teamId: post.teamId },
      });
      return { request: created, notes: rows };
    });

    await this.notifications.dispatch(notes);
    await this.scheduleExpiry(request.id, request.expiresAt, now);
    return {
      id: request.id,
      teamId: request.teamId,
      teamName: request.team.name,
      status: request.status,
      expiresAt: request.expiresAt,
    };
  }

  /** Các đội đang chờ nhận kèo (màn so sánh). Chỉ đội đăng kèo xem được. */
  async listForPost(
    me: TeamMembership,
    postId: string,
  ): Promise<MatchRequestDto[]> {
    const now = new Date();
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { teamId: true },
    });
    if (!post || post.teamId !== me.teamId) throw this.postNotFound();
    const rows = await this.prisma.matchRequest.findMany({
      where: { postId, ...livePending(now) },
      include: { team: { select: teamBriefSelect } },
      orderBy: { createdAt: 'asc' },
    });
    const stats = await teamStats(
      this.prisma,
      me.teamId,
      rows.map((r) => r.teamId),
      now,
    );
    return rows.map((r) => toRequestDto(r, stats.get(r.teamId), now));
  }

  /** Chi tiết yêu cầu, xem từ đội đăng kèo hoặc đội gửi. */
  async detail(
    me: TeamMembership,
    requestId: string,
  ): Promise<RequestDetailDto> {
    const now = new Date();
    const r = await this.prisma.matchRequest.findUnique({
      where: { id: requestId },
      include: {
        team: { select: teamBriefSelect },
        post: { include: postInclude(now) },
      },
    });
    const side =
      r?.post.teamId === me.teamId
        ? 'owner'
        : r?.teamId === me.teamId
          ? 'requester'
          : null;
    if (!r || !side) throw this.requestNotFound();

    const [stats, others, event] = await Promise.all([
      teamStats(this.prisma, r.post.teamId, [r.teamId], now),
      side === 'owner'
        ? this.prisma.matchRequest.findMany({
            where: { postId: r.postId, id: { not: r.id }, ...livePending(now) },
            orderBy: { createdAt: 'asc' },
            select: { team: { select: teamBriefSelect } },
          })
        : Promise.resolve([]),
      r.status === 'accepted' && r.post.type === 'find_opponent'
        ? this.prisma.event.findFirst({
            where: { teamId: me.teamId, match: { postId: r.postId } },
            select: { id: true },
          })
        : Promise.resolve(null),
    ]);
    const status = effectiveStatus(r, now);
    return {
      request: toRequestDto(r, stats.get(r.teamId), now),
      post: toPostDto(r.post),
      side,
      canRespond: status === 'pending' && MANAGER_ROLES.includes(me.role),
      otherPending: others.map((o) => o.team),
      eventId: event?.id,
    };
  }

  /**
   * Chấp nhận kèo trong một transaction: nhận yêu cầu → chốt kèo → tạo trận và
   * lịch cho hai đội → từ chối các yêu cầu khác → ghi thông báo. Đẩy sau commit.
   */
  async accept(
    me: TeamMembership,
    requestId: string,
  ): Promise<AcceptResultDto> {
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const r0 = await tx.matchRequest.findUnique({
        where: { id: requestId },
        select: { postId: true },
      });
      if (!r0) throw this.requestNotFound();
      await lockPost(tx, r0.postId);
      const r = await tx.matchRequest.findUniqueOrThrow({
        where: { id: requestId },
        include: requestInclude,
      });
      const post = r.post;
      if (post.teamId !== me.teamId) throw this.requestNotFound();
      if (post.status !== 'open') {
        throw this.conflict('post_not_open', 'Kèo đã có đối hoặc đã đóng');
      }
      if (effectiveStatus(r, now) !== 'pending') {
        throw this.conflict(
          'request_not_pending',
          'Yêu cầu đã hết hạn hoặc đã được trả lời',
        );
      }

      await tx.matchRequest.update({
        where: { id: r.id },
        data: { status: 'accepted', respondedAt: now },
      });
      await tx.post.update({
        where: { id: post.id },
        data: { status: 'matched' },
      });

      let matchId: string | undefined;
      let ownerEventId: string | undefined;
      let requesterEventId: string;
      const base = {
        startAt: post.startAt,
        endAt: post.endAt,
        location: post.pitchName,
        createdById: me.userId,
      };
      if (post.type === 'find_opponent') {
        const match = await tx.match.create({
          data: {
            postId: post.id,
            homeTeamId: post.teamId,
            awayTeamId: r.teamId,
            startAt: post.startAt,
            endAt: post.endAt,
            location: post.pitchName,
          },
        });
        matchId = match.id;
        const ownerEvent = await tx.event.create({
          data: {
            ...base,
            teamId: post.teamId,
            kind: 'match',
            title: `vs ${r.team.name}`,
            matchId,
          },
        });
        ownerEventId = ownerEvent.id;
        const requesterEvent = await tx.event.create({
          data: {
            ...base,
            teamId: r.teamId,
            kind: 'match',
            title: `vs ${post.team.name}`,
            matchId,
          },
        });
        requesterEventId = requesterEvent.id;
      } else {
        // Pass sân: chỉ đội nhận sân có lịch
        const requesterEvent = await tx.event.create({
          data: {
            ...base,
            teamId: r.teamId,
            kind: 'other',
            title: `Sân nhận từ ${post.team.name}`,
          },
        });
        requesterEventId = requesterEvent.id;
      }

      const others = await tx.matchRequest.findMany({
        where: { postId: post.id, id: { not: r.id }, ...livePending(now) },
        select: { id: true, teamId: true },
      });
      if (others.length) {
        await tx.matchRequest.updateMany({
          where: { id: { in: others.map((o) => o.id) } },
          data: { status: 'declined', respondedAt: now },
        });
      }

      const notes: NotificationRow[] = await writeNotifications(tx, {
        userIds: await teamManagerIds(tx, r.teamId),
        type: 'request.accepted',
        category: 'match',
        title: `${post.team.name} đã chốt kèo với đội bạn`,
        body: `${postLine(post)} · Đã vào lịch đội`,
        payload: {
          postId: post.id,
          requestId: r.id,
          teamId: r.teamId,
          matchId,
          eventId: requesterEventId,
        },
      });
      for (const o of others) {
        notes.push(
          ...(await writeNotifications(tx, {
            userIds: await teamManagerIds(tx, o.teamId),
            type: 'request.declined',
            category: 'match',
            title: `Kèo của ${post.team.name} đã có đối`,
            body: `${postLine(post)} · Thử nhận kèo khác trên Bảng tin`,
            payload: { postId: post.id, requestId: o.id, teamId: o.teamId },
          })),
        );
      }
      return {
        notes,
        requesterTeamId: r.teamId,
        dto: { matchId, eventId: ownerEventId },
      };
    });

    this.realtime.toTeam(me.teamId, 'events.changed', {});
    this.realtime.toTeam(result.requesterTeamId, 'events.changed', {});
    await this.notifications.dispatch(result.notes);
    return result.dto;
  }

  async decline(me: TeamMembership, requestId: string): Promise<void> {
    const now = new Date();
    const notes = await this.prisma.$transaction(async (tx) => {
      const r = await tx.matchRequest.findUnique({
        where: { id: requestId },
        include: requestInclude,
      });
      if (!r || r.post.teamId !== me.teamId) throw this.requestNotFound();
      const { count } = await tx.matchRequest.updateMany({
        where: { id: r.id, ...livePending(now) },
        data: { status: 'declined', respondedAt: now },
      });
      if (count === 0) {
        throw this.conflict(
          'request_not_pending',
          'Yêu cầu đã hết hạn hoặc đã được trả lời',
        );
      }
      return writeNotifications(tx, {
        userIds: await teamManagerIds(tx, r.teamId),
        type: 'request.declined',
        category: 'match',
        title: `${r.post.team.name} đã từ chối yêu cầu nhận kèo`,
        body: postLine(r.post),
        payload: { postId: r.postId, requestId: r.id, teamId: r.teamId },
      });
    });
    await this.notifications.dispatch(notes);
  }

  /** Đội gửi tự huỷ yêu cầu đang chờ. */
  async cancel(me: TeamMembership, requestId: string): Promise<void> {
    const now = new Date();
    const notes = await this.prisma.$transaction(async (tx) => {
      const r = await tx.matchRequest.findUnique({
        where: { id: requestId },
        include: requestInclude,
      });
      if (!r || r.teamId !== me.teamId) throw this.requestNotFound();
      const { count } = await tx.matchRequest.updateMany({
        where: { id: r.id, ...livePending(now) },
        data: { status: 'cancelled', respondedAt: now },
      });
      if (count === 0) {
        throw this.conflict(
          'request_not_pending',
          'Yêu cầu đã hết hạn hoặc đã được trả lời',
        );
      }
      return writeNotifications(tx, {
        userIds: await teamManagerIds(tx, r.post.teamId),
        type: 'request.cancelled',
        category: 'match',
        title: `${r.team.name} đã huỷ yêu cầu nhận kèo`,
        body: postLine(r.post),
        payload: { postId: r.postId, requestId: r.id, teamId: r.post.teamId },
      });
    });
    await this.notifications.dispatch(notes);
  }

  /** Job trễ đánh dấu hết hạn (đọc dữ liệu vẫn tự tính hết hạn nếu job trễ). */
  private async scheduleExpiry(requestId: string, expiresAt: Date, now: Date) {
    try {
      await this.queue.add(
        Jobs.requestExpire,
        { requestId },
        {
          delay: Math.max(0, expiresAt.getTime() - now.getTime()),
          jobId: `request-expire-${requestId}`,
          removeOnComplete: true,
          removeOnFail: 100,
        },
      );
    } catch (e) {
      this.logger.warn(`Không hẹn được job hết hạn: ${String(e)}`);
    }
  }

  private bad(code: string, message: string) {
    return new AppError(HttpStatus.BAD_REQUEST, code, message);
  }

  private conflict(code: string, message: string) {
    return new AppError(HttpStatus.CONFLICT, code, message);
  }

  private postNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'post_not_found',
      'Không tìm thấy kèo',
    );
  }

  private requestNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'request_not_found',
      'Không tìm thấy yêu cầu nhận kèo',
    );
  }
}
