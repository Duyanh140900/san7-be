import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import { Prisma } from '../generated/prisma/client.js';
import {
  notifyTeamManagers,
  resolveRequestNotifications,
} from '../notifications/notification-writer.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { MediaService } from '../media/media.service.js';
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
  FeedItemDto,
  FeedPageDto,
  FeedQuery,
  MyPostsQuery,
  PostDetailDto,
  PostDto,
} from './posts.dto.js';

type FeedCursor = { at: Date; id: string };

function decodeFeedCursor(value: string | undefined): FeedCursor | undefined {
  if (!value) return undefined;
  try {
    const [at, id] = Buffer.from(value, 'base64url').toString('utf8').split('|');
    const date = new Date(at);
    if (!id || Number.isNaN(date.getTime())) return undefined;
    return { at: date, id };
  } catch {
    return undefined;
  }
}

function encodeFeedCursor(cursor: FeedCursor): string {
  return Buffer.from(`${cursor.at.toISOString()}|${cursor.id}`).toString('base64url');
}

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
    private readonly media: MediaService,
  ) {}

  async create(me: TeamMembership, dto: CreatePostDto): Promise<PostDto> {
    const now = new Date();
    const mediaKeys = dto.mediaKeys ?? [];
    await this.media.assertUsablePostMedia(me.userId, mediaKeys);
    // Chọn từ sân đã đặt: giờ, sân lấy theo lượt đặt
    if (dto.bookingId && dto.type !== 'find_opponent') {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'booking_not_allowed',
        'Chỉ kèo tìm đối mới gắn với sân đã đặt',
      );
    }
    const booking = dto.bookingId
      ? await this.bookingFor(me.teamId, dto.bookingId, now)
      : null;
    const data = normalizePost(
      booking
        ? Object.assign({}, dto, {
            startAt: booking.startAt,
            endAt: booking.endAt,
          })
        : dto,
      now,
    );
    const team = await this.prisma.team.findUniqueOrThrow({
      where: { id: me.teamId },
      select: { area: true },
    });
    try {
      const post = await this.prisma.post.create({
        data: {
          ...data,
          teamId: me.teamId,
          authorId: me.userId,
          media: mediaKeys,
          area: dto.area || booking?.pitch.district || team.area,
          ...(booking
            ? {
                bookingId: booking.id,
                pitchId: booking.pitchId,
                pitchName: booking.pitch.name,
              }
            : {}),
        },
        include: postInclude(now),
      });
      return this.toPostDto(post);
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002' &&
        JSON.stringify(e.meta ?? {}).includes('booking_id')
      ) {
        throw new AppError(
          HttpStatus.CONFLICT,
          'booking_already_posted',
          'Sân này đã có kèo đăng rồi',
        );
      }
      throw e;
    }
  }

  /** Lượt đặt đã xác nhận của đội, chưa tới giờ, để đăng kèo. */
  private async bookingFor(teamId: string, bookingId: string, now: Date) {
    const b = await this.prisma.booking.findFirst({
      where: { id: bookingId, teamId },
      include: { pitch: { select: { name: true, district: true } } },
    });
    if (!b) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'booking_not_found',
        'Không tìm thấy lượt đặt sân',
      );
    }
    if (b.status !== 'confirmed' || b.startAt <= now) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'booking_not_usable',
        'Chỉ đăng kèo cho sân đã xác nhận và chưa tới giờ đá',
      );
    }
    return b;
  }

  /** Bảng tin: kèo đang mở, chưa tới giờ đá, mới nhất trước. */
  async feed(userId: string, q: FeedQuery): Promise<FeedPageDto> {
    const now = new Date();
    const limit = q.limit ?? 20;
    const cursor = decodeFeedCursor(q.cursor);
    const search = q.q?.trim();
    const postSearch = search
      ? {
          OR: [
            { team: { name: { contains: search, mode: 'insensitive' as const } } },
            { area: { contains: search, mode: 'insensitive' as const } },
            { pitchName: { contains: search, mode: 'insensitive' as const } },
            { pitch: { name: { contains: search, mode: 'insensitive' as const } } },
          ],
        }
      : {};
    const afterCursor = cursor
      ? {
          OR: [
            { createdAt: { lt: cursor.at } },
            { createdAt: cursor.at, id: { lt: cursor.id } },
          ],
        }
      : {};
    const myTeams = await this.prisma.teamMember.findMany({ where: { userId, status: 'active' }, select: { teamId: true } });
    const blocked = myTeams.length ? await this.prisma.teamBlock.findMany({ where: { blockerTeamId: { in: myTeams.map((team) => team.teamId) } }, select: { blockedTeamId: true } }) : [];
    const blockedTeamIds = blocked.map((row) => row.blockedTeamId);
    const type = q.kind ?? q.type;
    const levelOrder = ['sieu_yeu', 'yeu', 'tby', 'tb', 'tbk', 'gioi'];
    const timeRange = q.timeSlot === 'morning' ? [0, 12] : q.timeSlot === 'afternoon' ? [12, 18] : q.timeSlot === 'evening' ? [18, 24] : undefined;
    const dateRange = q.date ? { gte: new Date(`${q.date}T00:00:00+07:00`), lt: new Date(`${q.date}T00:00:00+07:00`).getTime() + 86_400_000 } : undefined;
    const where = {
        status: 'open',
        ...(blockedTeamIds.length ? { teamId: { notIn: blockedTeamIds } } : {}),
        startAt: dateRange ? { gte: dateRange.gte, lt: new Date(dateRange.lt) } : { gt: now },
        ...(type ? { type } : {}),
        ...(q.area ? { area: q.area } : {}),
        ...(q.ratioType ? { deal: q.ratioType } : {}),
        ...(q.levelMin || q.levelMax ? { level: { in: levelOrder.slice(q.levelMin ? levelOrder.indexOf(q.levelMin) : 0, (q.levelMax ? levelOrder.indexOf(q.levelMax) : levelOrder.length - 1) + 1) } } : {}),
        ...(q.minRating ? { team: { reviewsReceived: { some: { reputation: { gte: Math.ceil(q.minRating) } } } } } : {}),
        AND: [postSearch, afterCursor],
      } as Prisma.PostWhereInput;
    const [rows, total] = await Promise.all([this.prisma.post.findMany({
      where,
      include: {
        ...postInclude(now),
        applications: {
          where: { userId },
          select: { status: true },
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    }), this.prisma.post.count({ where: { ...where, AND: [postSearch] } })]);
    const timeFilteredRows = timeRange ? rows.filter((post) => { const hour = post.startAt.getUTCHours() + 7; return hour >= timeRange[0] && hour < timeRange[1]; }) : rows;
    const resultSearch = search
      ? {
          OR: [
            { homeTeam: { name: { contains: search, mode: 'insensitive' as const } } },
            { awayTeam: { name: { contains: search, mode: 'insensitive' as const } } },
            {
              post: {
                is: {
                  OR: [
                    { area: { contains: search, mode: 'insensitive' as const } },
                    { pitchName: { contains: search, mode: 'insensitive' as const } },
                    { pitch: { name: { contains: search, mode: 'insensitive' as const } } },
                  ],
                },
              },
            },
          ],
        }
      : {};
    const resultCursor = cursor
      ? {
          OR: [
            { confirmedAt: { lt: cursor.at } },
            { confirmedAt: cursor.at, id: { lt: cursor.id } },
          ],
        }
      : {};
    const matches = await this.prisma.match.findMany({
      where: {
        status: 'finished',
        confirmedAt: { not: null },
        homeScore: { not: null },
        awayScore: { not: null },
        AND: [resultSearch, resultCursor],
      },
      include: {
        homeTeam: { select: teamBriefSelect },
        awayTeam: { select: teamBriefSelect },
        stats: {
          where: { goals: { gt: 0 } },
          select: { goals: true, mvp: true, user: { select: { name: true } } },
          orderBy: [{ goals: 'desc' }, { userId: 'asc' }],
        },
      },
      orderBy: [{ confirmedAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
    });
    const feedRows: { item: FeedItemDto; at: Date; id: string }[] = [
      ...timeFilteredRows.map((post) => ({
        item: {
          ...this.toPostDto(post),
          myApplicationStatus: post.applications[0]?.status,
        },
        at: post.createdAt,
        id: post.id,
      })),
      ...matches.map((match) => ({
        item: {
          kind: 'match_result' as const,
          result: {
            matchId: match.id,
            playedAt: match.startAt,
            teamA: { ...match.homeTeam, score: match.homeScore! },
            teamB: { ...match.awayTeam, score: match.awayScore! },
            scorers: match.stats.map((stat) => ({
              name: stat.user.name,
              goals: stat.goals,
            })),
            mvpName: match.stats.find((stat) => stat.mvp)?.user.name ?? null,
          },
        },
        at: match.confirmedAt!,
        id: match.id,
      })),
    ].sort((a, b) => b.at.getTime() - a.at.getTime() || b.id.localeCompare(a.id));
    const page = feedRows.slice(0, limit);
    return {
      items: page.map((row) => row.item),
      nextCursor:
        feedRows.length > limit
          ? encodeFeedCursor({ at: page[page.length - 1].at, id: page[page.length - 1].id })
          : undefined,
      total,
    };
  }

  /** Kèo do chính tài khoản tạo, hỗ trợ lọc trạng thái và cursor. */
  async myPosts(userId: string, q: MyPostsQuery): Promise<FeedPageDto> {
    const now = new Date();
    const limit = q.limit ?? 20;
    const rows = await this.prisma.post.findMany({
      where: { authorId: userId, ...(q.status ? { status: q.status } : {}) },
      include: postInclude(now), orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: limit + 1,
      ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const items = rows.slice(0, limit);
    return {
      items: items.map((post) => this.toPostDto(post)),
      nextCursor: rows.length > limit ? items.at(-1)?.id : undefined,
      total: items.length,
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
    const [mine, pending, myApplication, venue, attendance] = await Promise.all([
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
      this.prisma.postApplication.findUnique({
        where: { postId_userId: { postId, userId } },
        select: { status: true },
      }),
      post.pitchId
        ? this.prisma.$queryRaw<{ lat: number; lng: number }[]>`
            SELECT ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng
            FROM pitches WHERE id = ${post.pitchId}::uuid
          `
        : Promise.resolve([]),
      this.prisma.attendance.findMany({
        where: {
          status: 'go',
          event: {
            teamId: post.teamId,
            OR: [
              ...(post.bookingId ? [{ bookingId: post.bookingId }] : []),
              { match: { postId } },
            ],
          },
        },
        select: {
          userId: true,
          user: { select: { name: true, position: true } },
        },
        orderBy: { user: { name: 'asc' } },
      }),
    ]);
    return {
      post: this.toPostDto(post),
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
      myApplicationStatus: myApplication?.status,
      requestTeams: pending.map((r) => r.team),
      venueLat: venue[0]?.lat ?? null,
      venueLng: venue[0]?.lng ?? null,
      lineup: attendance.map((a) => ({
        userId: a.userId,
        name: a.user.name,
        position: a.user.position,
      })),
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
        // Nhả sân đã gắn: để đổi giờ/huỷ được và đăng kèo lại
        data: { status: 'closed', bookingId: null },
      });
      const pending = await tx.matchRequest.updateManyAndReturn({
        where: { postId, ...livePending(now) },
        data: { status: 'declined', respondedAt: now },
        select: { id: true, teamId: true },
      });
      if (pending.length === 0) return [];
      await resolveRequestNotifications(
        tx,
        pending.map((r) => r.id),
        now,
      );
      return notifyTeamManagers(
        tx,
        pending.map((r) => ({
          teamId: r.teamId,
          payload: { postId, requestId: r.id, teamId: r.teamId },
        })),
        {
          type: 'post.closed',
          category: 'match',
          title: `${post.team.name} đã đóng kèo`,
          body: postLine(post),
        },
      );
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

  private toPostDto(post: Parameters<typeof toPostDto>[0]): PostDto {
    return toPostDto(post, (key) => this.media.publicUrlFor(key));
  }
}
