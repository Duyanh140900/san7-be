import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { AttendanceStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type {
  AttendanceCountsDto,
  AttendeeDto,
  CreateEventDto,
  EventDetailDto,
  EventSummaryDto,
  ListEventsQuery,
  SetAttendanceDto,
  UpdateEventDto,
} from './events.dto.js';

type EventRow = {
  id: string;
  kind: EventSummaryDto['kind'];
  title: string;
  startAt: Date;
  endAt: Date;
  location: string | null;
  note: string | null;
  minPlayers: number | null;
};

const MAX_DURATION_MS = 24 * 3_600_000;

/** Đếm câu trả lời, chỉ tính người đang là thành viên active. */
export function countAttendance(
  activeUserIds: Set<string>,
  answers: { userId: string; status: AttendanceStatus }[],
): AttendanceCountsDto {
  const counts = { go: 0, maybe: 0, no: 0, pending: 0 };
  let answered = 0;
  for (const a of answers) {
    if (!activeUserIds.has(a.userId)) continue;
    counts[a.status]++;
    answered++;
  }
  counts.pending = activeUserIds.size - answered;
  return counts;
}

@Injectable()
export class EventsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async list(
    me: TeamMembership,
    q: ListEventsQuery,
  ): Promise<EventSummaryDto[]> {
    const now = new Date();
    const upcoming = (q.scope ?? 'upcoming') === 'upcoming';
    const events = await this.prisma.event.findMany({
      where: {
        teamId: me.teamId,
        ...(upcoming ? { endAt: { gte: now } } : { endAt: { lt: now } }),
      },
      orderBy: { startAt: upcoming ? 'asc' : 'desc' },
      take: q.limit ?? 20,
    });
    if (events.length === 0) return [];
    const [active, answers] = await Promise.all([
      this.activeUserIds(me.teamId),
      this.prisma.attendance.findMany({
        where: { eventId: { in: events.map((e) => e.id) } },
        select: { eventId: true, userId: true, status: true },
      }),
    ]);
    return events.map((e) => {
      const mine = answers.filter((a) => a.eventId === e.id);
      return this.toSummary(
        e,
        countAttendance(active, mine),
        mine.find((a) => a.userId === me.userId)?.status ?? null,
      );
    });
  }

  async detail(me: TeamMembership, eventId: string): Promise<EventDetailDto> {
    const event = await this.findEvent(me.teamId, eventId);
    const [members, answers] = await Promise.all([
      this.prisma.teamMember.findMany({
        where: { teamId: me.teamId, status: 'active' },
        include: { user: true },
      }),
      this.prisma.attendance.findMany({ where: { eventId } }),
    ]);
    const byUser = new Map(answers.map((a) => [a.userId, a]));
    const order: Record<string, number> = { go: 0, maybe: 1, no: 2 };
    const attendees: AttendeeDto[] = members
      .map((m) => {
        const a = byUser.get(m.userId);
        return {
          userId: m.userId,
          name: m.user.name,
          avatarUrl: m.user.avatarUrl,
          position: m.user.position,
          status: a?.status ?? null,
          note: a?.note ?? null,
        };
      })
      .sort(
        (x, y) =>
          (x.userId === me.userId ? -1 : 0) -
            (y.userId === me.userId ? -1 : 0) ||
          (order[x.status ?? ''] ?? 3) - (order[y.status ?? ''] ?? 3) ||
          x.name.localeCompare(y.name, 'vi'),
      );
    const active = new Set(members.map((m) => m.userId));
    const summary = this.toSummary(
      event,
      countAttendance(active, answers),
      byUser.get(me.userId)?.status ?? null,
    );
    return Object.assign(summary, { attendees });
  }

  async create(
    me: TeamMembership,
    dto: CreateEventDto,
  ): Promise<EventSummaryDto> {
    this.checkTimes(dto.startAt, dto.endAt);
    const event = await this.prisma.event.create({
      data: {
        kind: dto.kind,
        title: dto.title,
        startAt: dto.startAt,
        endAt: dto.endAt,
        location: dto.location ?? null,
        note: dto.note ?? null,
        minPlayers: dto.minPlayers ?? null,
        teamId: me.teamId,
        createdById: me.userId,
      },
    });
    this.realtime.toTeam(me.teamId, 'events.changed', { eventId: event.id });
    const active = await this.activeUserIds(me.teamId);
    return this.toSummary(event, countAttendance(active, []), null);
  }

  async update(
    me: TeamMembership,
    eventId: string,
    dto: UpdateEventDto,
  ): Promise<EventDetailDto> {
    const event = await this.findEvent(me.teamId, eventId);
    this.checkTimes(dto.startAt ?? event.startAt, dto.endAt ?? event.endAt);
    await this.prisma.event.update({ where: { id: eventId }, data: dto });
    this.realtime.toTeam(me.teamId, 'events.changed', { eventId });
    return this.detail(me, eventId);
  }

  async remove(me: TeamMembership, eventId: string): Promise<void> {
    const { count } = await this.prisma.event.deleteMany({
      where: { id: eventId, teamId: me.teamId },
    });
    if (count === 0) throw this.notFound();
    this.realtime.toTeam(me.teamId, 'events.changed', { eventId });
  }

  /** Điểm danh của chính mình. Trận đã kết thúc thì không đổi được. */
  async setAttendance(
    me: TeamMembership,
    eventId: string,
    dto: SetAttendanceDto,
  ): Promise<AttendanceCountsDto> {
    const event = await this.findEvent(me.teamId, eventId);
    if (event.endAt.getTime() < Date.now()) {
      throw new AppError(
        HttpStatus.CONFLICT,
        'event_finished',
        'Lịch này đã kết thúc, không đổi điểm danh được',
      );
    }
    await this.prisma.attendance.upsert({
      where: { eventId_userId: { eventId, userId: me.userId } },
      create: {
        eventId,
        userId: me.userId,
        status: dto.status,
        note: dto.note ?? null,
      },
      update: { status: dto.status, note: dto.note ?? null },
    });
    const [active, answers] = await Promise.all([
      this.activeUserIds(me.teamId),
      this.prisma.attendance.findMany({
        where: { eventId },
        select: { userId: true, status: true },
      }),
    ]);
    const counts = countAttendance(active, answers);
    this.realtime.toTeam(me.teamId, 'attendance.updated', {
      eventId,
      userId: me.userId,
      status: dto.status,
      counts,
    });
    return counts;
  }

  private async activeUserIds(teamId: string): Promise<Set<string>> {
    const rows = await this.prisma.teamMember.findMany({
      where: { teamId, status: 'active' },
      select: { userId: true },
    });
    return new Set(rows.map((r) => r.userId));
  }

  private async findEvent(teamId: string, eventId: string) {
    const event = await this.prisma.event.findFirst({
      where: { id: eventId, teamId },
    });
    if (!event) throw this.notFound();
    return event;
  }

  private checkTimes(startAt: Date, endAt: Date) {
    const ms = endAt.getTime() - startAt.getTime();
    if (ms <= 0 || ms > MAX_DURATION_MS) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'invalid_event_time',
        'Giờ kết thúc phải sau giờ bắt đầu và không quá 24 tiếng',
      );
    }
  }

  private toSummary(
    e: EventRow,
    counts: AttendanceCountsDto,
    myStatus: AttendanceStatus | null,
  ): EventSummaryDto {
    return {
      id: e.id,
      kind: e.kind,
      title: e.title,
      startAt: e.startAt,
      endAt: e.endAt,
      location: e.location,
      note: e.note,
      minPlayers: e.minPlayers,
      counts,
      myStatus,
    };
  }

  private notFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'event_not_found',
      'Không tìm thấy lịch',
    );
  }
}
