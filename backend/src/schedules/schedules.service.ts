import { InjectQueue } from '@nestjs/bullmq';
import { HttpStatus, Injectable } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { Prisma, PostSchedule } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaService } from '../media/media.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { normalizePost } from '../posts/posts.service.js';
import type { CreatePostDto } from '../posts/posts.dto.js';
import type { CreatePostScheduleDto, PostScheduleDto } from './schedules.dto.js';

type StoredPost = Omit<CreatePostDto, 'startAt' | 'endAt'> & { startAt: string; endAt: string };
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

function toStored(dto: CreatePostDto): StoredPost {
  return {
    type: dto.type,
    startAt: dto.startAt.toISOString(),
    endAt: dto.endAt.toISOString(),
    pitchName: dto.pitchName,
    area: dto.area,
    level: dto.level,
    deal: dto.deal,
    ratioWin: dto.ratioWin,
    ratioLose: dto.ratioLose,
    pitchPrice: dto.pitchPrice,
    positions: dto.positions,
    playersNeeded: dto.playersNeeded,
    body: dto.body,
    bookingId: dto.bookingId,
    mediaKeys: dto.mediaKeys,
  };
}

function fromStored(payload: Prisma.JsonValue): CreatePostDto {
  const raw = payload as unknown as StoredPost;
  return {
    type: raw.type,
    startAt: new Date(raw.startAt),
    endAt: new Date(raw.endAt),
    pitchName: raw.pitchName,
    area: raw.area,
    level: raw.level,
    deal: raw.deal,
    ratioWin: raw.ratioWin,
    ratioLose: raw.ratioLose,
    pitchPrice: raw.pitchPrice,
    positions: raw.positions,
    playersNeeded: raw.playersNeeded,
    body: raw.body,
    bookingId: raw.bookingId,
    mediaKeys: raw.mediaKeys,
  };
}

function withTimes(
  dto: CreatePostDto,
  startAt: Date,
  endAt: Date,
): CreatePostDto {
  return {
    type: dto.type,
    startAt,
    endAt,
    pitchName: dto.pitchName,
    area: dto.area,
    level: dto.level,
    deal: dto.deal,
    ratioWin: dto.ratioWin,
    ratioLose: dto.ratioLose,
    pitchPrice: dto.pitchPrice,
    positions: dto.positions,
    playersNeeded: dto.playersNeeded,
    body: dto.body,
    bookingId: dto.bookingId,
    mediaKeys: dto.mediaKeys,
  };
}

function toDto(row: PostSchedule): PostScheduleDto {
  return {
    id: row.id, teamId: row.teamId, scheduledAt: row.scheduledAt,
    repeatWeekly: row.repeatWeekly, status: row.status,
    publishedPostId: row.publishedPostId,
    post: fromStored(row.payload),
  };
}

export function postScheduleJobId(id: string, scheduledAt: Date): string {
  return `post-schedule-${id}-${scheduledAt.getTime()}`;
}

@Injectable()
export class PostSchedulesService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
    private readonly media: MediaService,
  ) {}

  async create(me: TeamMembership, dto: CreatePostScheduleDto): Promise<PostScheduleDto> {
    this.assertFuture(dto.scheduledAt);
    normalizePost(dto, new Date(dto.scheduledAt.getTime() - 1));
    await this.media.assertUsablePostMedia(me.userId, dto.mediaKeys ?? []);
    const row = await this.prisma.postSchedule.create({
      data: { teamId: me.teamId, authorId: me.userId, payload: toStored(dto), scheduledAt: dto.scheduledAt, repeatWeekly: dto.repeatWeekly ?? false },
    });
    await this.enqueue(row.id, row.scheduledAt);
    return toDto(row);
  }

  async list(me: TeamMembership): Promise<PostScheduleDto[]> {
    const rows = await this.prisma.postSchedule.findMany({
      where: { teamId: me.teamId, status: 'scheduled' },
      orderBy: { scheduledAt: 'asc' },
    });
    return rows.map(toDto);
  }

  async update(me: TeamMembership, id: string, dto: CreatePostScheduleDto): Promise<PostScheduleDto> {
    const existing = await this.mine(me, id);
    this.assertFuture(dto.scheduledAt);
    normalizePost(dto, new Date(dto.scheduledAt.getTime() - 1));
    await this.media.assertUsablePostMedia(me.userId, dto.mediaKeys ?? []);
    const row = await this.prisma.postSchedule.update({
      where: { id: existing.id },
      data: { payload: toStored(dto), scheduledAt: dto.scheduledAt, repeatWeekly: dto.repeatWeekly ?? false },
    });
    await this.queue.remove(postScheduleJobId(existing.id, existing.scheduledAt)).catch(() => undefined);
    await this.enqueue(id, row.scheduledAt);
    return toDto(row);
  }

  async cancel(me: TeamMembership, id: string): Promise<void> {
    const existing = await this.mine(me, id);
    await this.prisma.postSchedule.update({ where: { id }, data: { status: 'cancelled' } });
    await this.queue.remove(postScheduleJobId(existing.id, existing.scheduledAt)).catch(() => undefined);
  }

  private async mine(me: TeamMembership, id: string): Promise<PostSchedule> {
    const row = await this.prisma.postSchedule.findFirst({ where: { id, teamId: me.teamId, status: 'scheduled' } });
    if (!row) throw new AppError(HttpStatus.NOT_FOUND, 'post_schedule_not_found', 'Không tìm thấy lịch đăng');
    return row;
  }

  private assertFuture(at: Date) {
    if (at <= new Date()) throw new AppError(HttpStatus.BAD_REQUEST, 'schedule_in_past', 'Giờ đăng phải ở tương lai');
  }

  private enqueue(id: string, at: Date) {
    return this.queue.add(Jobs.postSchedulePublish, { scheduleId: id }, {
      jobId: postScheduleJobId(id, at), delay: Math.max(0, at.getTime() - Date.now()),
      attempts: 3, removeOnComplete: true, removeOnFail: 100,
    });
  }
}

/** Worker-safe: khóa lịch, công bố đúng một lần; lịch tuần sẽ dời cả lịch lẫn giờ đá. */
export async function publishPostSchedule(prisma: PrismaService, scheduleId: string, now = new Date()) {
  return prisma.$transaction(async (tx) => {
    // Claim trước khi tạo Post. Hai worker có thể cùng nhận job nhưng chỉ một
    // worker đổi được scheduled -> cancelled; transaction còn lại không tạo bài.
    const claimed = await tx.postSchedule.updateMany({
      where: { id: scheduleId, status: 'scheduled', scheduledAt: { lte: now } },
      data: { status: 'cancelled' },
    });
    if (claimed.count !== 1) return { published: false, nextAt: null };
    const schedule = await tx.postSchedule.findUniqueOrThrow({ where: { id: scheduleId } });
    const author = await tx.teamMember.findFirst({
      where: {
        teamId: schedule.teamId,
        userId: schedule.authorId,
        status: 'active',
        role: { in: ['captain', 'vice'] },
      },
      select: { userId: true },
    });
    if (!author) return { published: false, nextAt: null };
    const dto = fromStored(schedule.payload);
    // Misfire policy: one-time schedule expires; weekly schedule skips every
    // missed occurrence and continues from the first future kick-off.
    if (dto.startAt <= now) {
      if (!schedule.repeatWeekly) return { published: false, nextAt: null };
      const periods = Math.floor((now.getTime() - dto.startAt.getTime()) / WEEK_MS) + 1;
      const nextDto = withTimes(
        dto,
        new Date(dto.startAt.getTime() + periods * WEEK_MS),
        new Date(dto.endAt.getTime() + periods * WEEK_MS),
      );
      const nextAt = new Date(schedule.scheduledAt.getTime() + periods * WEEK_MS);
      await tx.postSchedule.update({
        where: { id: schedule.id },
        data: { status: 'scheduled', payload: toStored(nextDto), scheduledAt: nextAt },
      });
      return { published: false, nextAt };
    }
    const data = normalizePost(dto, now);
    const team = await tx.team.findUniqueOrThrow({ where: { id: schedule.teamId }, select: { area: true } });
    const post = await tx.post.create({ data: { ...data, teamId: schedule.teamId, authorId: schedule.authorId, area: dto.area || team.area, media: dto.mediaKeys ?? [] } });
    if (!schedule.repeatWeekly) {
      await tx.postSchedule.update({ where: { id: schedule.id }, data: { status: 'cancelled', publishedPostId: post.id } });
      return { published: true, nextAt: null };
    }
    const nextDto = withTimes(
      dto,
      new Date(dto.startAt.getTime() + WEEK_MS),
      new Date(dto.endAt.getTime() + WEEK_MS),
    );
    const nextAt = new Date(schedule.scheduledAt.getTime() + WEEK_MS);
    await tx.postSchedule.update({ where: { id: schedule.id }, data: { status: 'scheduled', payload: toStored(nextDto), scheduledAt: nextAt } });
    return { published: true, nextAt };
  });
}
