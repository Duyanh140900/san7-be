import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { Prisma } from '../generated/prisma/client.js';
import {
  resolveRequestNotifications,
  teamManagerIds,
  writeNotifications,
} from '../notifications/notification-writer.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  effectiveStatus,
  livePending,
  postInclude,
  postLine,
  teamBriefSelect,
  toPostDto,
} from './post-mapper.js';
import type {
  CreatePostDto,
  FeedPageDto,
  FeedQuery,
  PostDetailDto,
  PostDto,
} from './posts.dto.js';

const MAX_DURATION_MS = 6 * 3_600_000;
const MAX_AHEAD_MS = 60 * 86_400_000;

function bad(code: string, message: string) {
  return new AppError(HttpStatus.BAD_REQUEST, code, message);
}

/** Chuẩn hoá các trường phụ thuộc loại kèo; ném lỗi nếu thiếu. */
export function normalizePost(
  dto: CreatePostDto,
  now: Date,
): Omit<Prisma.PostUncheckedCreateInput, 'teamId' | 'authorId' | 'area'> {
  if (dto.endAt <= dto.startAt) {
    throw bad('invalid_time', 'Giờ kết thúc phải sau giờ bắt đầu');
  }
  if (dto.endAt.getTime() - dto.startAt.getTime() > MAX_DURATION_MS) {
    throw bad('invalid_time', 'Một kèo dài tối đa 6 giờ');
  }
  if (dto.startAt <= now) {
    throw bad('invalid_time', 'Giờ đá phải ở tương lai');
  }
  if (dto.startAt.getTime() - now.getTime() > MAX_AHEAD_MS) {
    throw bad('invalid_time', 'Chỉ đăng kèo trong vòng 60 ngày tới');
  }

  const base = {
    type: dto.type,
    startAt: dto.startAt,
    endAt: dto.endAt,
    pitchName: dto.pitchName || null,
    level: dto.level,
    body: dto.body || null,
    pitchPrice: dto.pitchPrice === undefined ? null : BigInt(dto.pitchPrice),
    deal: null as CreatePostDto['deal'] | null,
    ratioWin: null as number | null,
    ratioLose: null as number | null,
    positions: [] as NonNullable<CreatePostDto['positions']>,
    playersNeeded: null as number | null,
  };

  switch (dto.type) {
    case 'find_opponent': {
      if (!dto.deal) throw bad('deal_required', 'Chọn hình thức kèo');
      base.deal = dto.deal;
      if (dto.deal === 'split') {
        if (
          dto.ratioWin === undefined ||
          dto.ratioLose === undefined ||
          dto.ratioWin + dto.ratioLose !== 100
        ) {
          throw bad('invalid_ratio', 'Tỷ lệ chia phải cộng lại bằng 100');
        }
        base.ratioWin = dto.ratioWin;
        base.ratioLose = dto.ratioLose;
      } else if (dto.deal === 'loser_pays') {
        base.ratioWin = 0;
        base.ratioLose = 100;
      }
      return base;
    }
    case 'recruit': {
      const positions = [...new Set(dto.positions ?? [])];
      if (positions.length === 0 && !dto.playersNeeded) {
        throw bad('recruit_details_required', 'Chọn vị trí hoặc số người cần');
      }
      base.positions = positions;
      base.playersNeeded = dto.playersNeeded ?? null;
      return base;
    }
    case 'pass_pitch': {
      if (!base.pitchName) {
        throw bad('pitch_required', 'Nhập tên sân muốn pass');
      }
      return base;
    }
  }
}

@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(me: TeamMembership, dto: CreatePostDto): Promise<PostDto> {
    const now = new Date();
    const data = normalizePost(dto, now);
    const team = await this.prisma.team.findUniqueOrThrow({
      where: { id: me.teamId },
      select: { area: true },
    });
    const post = await this.prisma.post.create({
      data: {
        ...data,
        teamId: me.teamId,
        authorId: me.userId,
        area: dto.area || team.area,
      },
      include: postInclude(now),
    });
    return toPostDto(post);
  }

  /** Bảng tin: kèo đang mở, chưa tới giờ đá, mới nhất trước. */
  async feed(q: FeedQuery): Promise<FeedPageDto> {
    const now = new Date();
    const limit = q.limit ?? 20;
    const rows = await this.prisma.post.findMany({
      where: {
        status: 'open',
        startAt: { gt: now },
        ...(q.type ? { type: q.type } : {}),
        ...(q.area ? { area: q.area } : {}),
      },
      include: postInclude(now),
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, limit);
    return {
      items: page.map(toPostDto),
      nextCursor: rows.length > limit ? page[page.length - 1].id : undefined,
    };
  }

  async detail(userId: string, postId: string): Promise<PostDetailDto> {
    const now = new Date();
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: postInclude(now),
    });
    if (!post) throw this.notFound();

    const managed = await this.prisma.teamMember.findMany({
      where: { userId, status: 'active', role: { in: ['captain', 'vice'] } },
      select: { teamId: true },
    });
    const managedIds = managed.map((m) => m.teamId);
    const [mine, pending] = await Promise.all([
      this.prisma.matchRequest.findFirst({
        where: { postId, teamId: { in: managedIds } },
        orderBy: { createdAt: 'desc' },
        include: { team: { select: { name: true } } },
      }),
      this.prisma.matchRequest.findMany({
        where: { postId, ...livePending(now) },
        orderBy: { createdAt: 'asc' },
        take: 5,
        select: { team: { select: teamBriefSelect } },
      }),
    ]);
    return {
      post: toPostDto(post),
      canManage: managedIds.includes(post.teamId),
      myRequest: mine
        ? {
            id: mine.id,
            teamId: mine.teamId,
            teamName: mine.team.name,
            status: effectiveStatus(mine, now),
            expiresAt: mine.expiresAt,
          }
        : undefined,
      requestTeams: pending.map((r) => r.team),
    };
  }

  /** Đóng kèo (đội trưởng/phó của đội đăng). Các yêu cầu đang chờ bị từ chối. */
  async close(me: TeamMembership, postId: string): Promise<void> {
    const now = new Date();
    const notes = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT 1 AS locked FROM posts WHERE id = ${postId}::uuid FOR UPDATE`;
      const post = await tx.post.findUnique({
        where: { id: postId },
        include: { team: { select: { name: true } } },
      });
      if (!post || post.teamId !== me.teamId) throw this.notFound();
      if (post.status !== 'open') {
        throw new AppError(
          HttpStatus.CONFLICT,
          'post_not_open',
          'Kèo đã chốt hoặc đã đóng',
        );
      }
      await tx.post.update({
        where: { id: postId },
        data: { status: 'closed' },
      });
      const pending = await tx.matchRequest.findMany({
        where: { postId, ...livePending(now) },
        select: { id: true, teamId: true },
      });
      if (pending.length === 0) return [];
      await tx.matchRequest.updateMany({
        where: { id: { in: pending.map((r) => r.id) } },
        data: { status: 'declined', respondedAt: now },
      });
      await resolveRequestNotifications(
        tx,
        pending.map((r) => r.id),
        now,
      );
      const rows = [];
      for (const r of pending) {
        rows.push(
          ...(await writeNotifications(tx, {
            userIds: await teamManagerIds(tx, r.teamId),
            type: 'post.closed',
            category: 'match',
            title: `${post.team.name} đã đóng kèo`,
            body: postLine(post),
            payload: { postId, requestId: r.id, teamId: r.teamId },
          })),
        );
      }
      return rows;
    });
    await this.notifications.dispatch(notes);
  }

  private notFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'post_not_found',
      'Không tìm thấy kèo',
    );
  }
}
