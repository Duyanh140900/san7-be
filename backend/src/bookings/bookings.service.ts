import { randomInt } from 'node:crypto';
import { InjectQueue } from '@nestjs/bullmq';
import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import type { Queue } from 'bullmq';
import { AppError } from '../common/errors.js';
import { toMoney } from '../common/money.js';
import type { TeamMembership } from '../common/team-member.guard.js';
import { vnShort } from '../common/vn-time.js';
import { Prisma } from '../generated/prisma/client.js';
import {
  teamMemberIds,
  writeNotifications,
} from '../notifications/notification-writer.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import { matchTemplate, parseSlots } from '../pitches/pitch-slots.js';
import type {
  BookingDto,
  CreateBookingDto,
  ListBookingsQuery,
} from './bookings.dto.js';

type Tx = Prisma.TransactionClient;

/** Giữ chỗ 10 phút để xác nhận. */
export const HOLD_MS = 10 * 60_000;
const MAX_ACTIVE_HOLDS = 3;
const MAX_AHEAD_MS = 30 * 86_400_000;
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

const bookingInclude = {
  pitch: { select: { id: true, name: true, district: true, address: true, bankBin: true, accountNo: true, accountName: true } },
  post: { select: { id: true, status: true } },
  event: { select: { id: true } },
} as const satisfies Prisma.BookingInclude;

type BookingRow = Prisma.BookingGetPayload<{ include: typeof bookingInclude }>;

export function newBookingCode(): string {
  let s = '';
  for (let i = 0; i < 4; i++)
    s += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return `SC-${s}`;
}
const servicePrices = { water: 20_000, bib: 50_000 } as const;

const slotKeyOf = (pitchId: string, courtNo: number, startAt: Date) =>
  `${pitchId}:${courtNo}:${startAt.toISOString()}`;

/** Điều kiện lượt đặt đang chiếm chỗ: đã xác nhận hoặc đang giữ chưa hết hạn. */
const active = (now: Date) =>
  ({
    OR: [
      { status: 'confirmed' },
      { status: 'held', heldUntil: { gt: now } },
      { status: 'deposit_claimed', heldUntil: { gt: now } },
    ],
  }) as const satisfies Prisma.BookingWhereInput;

/** Nhả một lượt giữ chỗ đã hết hạn. Dùng chung cho worker. */
export async function expireHold(
  prisma: Pick<Prisma.TransactionClient, 'booking'>,
  bookingId: string,
  now: Date,
): Promise<boolean> {
  const { count } = await prisma.booking.updateMany({
    where: { id: bookingId, status: 'held', heldUntil: { lte: now } },
    data: {
      status: 'cancelled',
      slotKey: null,
      heldUntil: null,
      cancelledAt: now,
    },
  });
  return count > 0;
}

function isUniqueViolation(e: unknown, field: string): boolean {
  if (
    !(e instanceof Prisma.PrismaClientKnownRequestError) ||
    e.code !== 'P2002'
  ) {
    return false;
  }
  return JSON.stringify(e.meta ?? {}).includes(field);
}

@Injectable()
export class BookingsService {
  private readonly logger = new Logger(BookingsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly realtime: RealtimeService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
  ) {}

  /** Giữ chỗ 10 phút cho đội. Chưa tính là đặt: phải xác nhận trước khi hết hạn. */
  async hold(me: TeamMembership, dto: CreateBookingDto): Promise<BookingDto> {
    const now = new Date();
    const pitch = await this.prisma.pitch.findUnique({
      where: { id: dto.pitchId },
      select: { id: true, courtsCount: true, slotMinutes: true, slots: true },
    });
    if (!pitch) throw this.pitchNotFound();
    const price = this.priceOf(pitch.slots, dto.startAt, now);
    const services = [...new Set(dto.services ?? [])];
    const extraAmount = services.reduce((total, service) => total + servicePrices[service], 0);
    const endAt = new Date(dto.startAt.getTime() + pitch.slotMinutes * 60_000);

    const created = await this.withCodeRetry((code) =>
      this.prisma.$transaction(async (tx) => {
        // Khoá theo đội để hai yêu cầu cùng lúc không vượt giới hạn số lượt giữ
        await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtext(${`holds:${me.teamId}`}))`;
        const holds = await tx.booking.count({
          where: { teamId: me.teamId, status: 'held', heldUntil: { gt: now } },
        });
        if (holds >= MAX_ACTIVE_HOLDS) {
          throw this.conflict(
            'too_many_holds',
            'Đội bạn đang giữ quá nhiều sân chưa xác nhận. Xác nhận hoặc đợi hết hạn.',
          );
        }
        await this.lockSlot(tx, pitch.id, dto.startAt);
        const dup = await tx.booking.findFirst({
          where: {
            teamId: me.teamId,
            pitchId: pitch.id,
            startAt: dto.startAt,
            ...active(now),
          },
          select: { id: true },
        });
        if (dup) {
          throw this.conflict(
            'already_booked',
            'Đội bạn đã giữ hoặc đặt khung giờ này rồi',
          );
        }
        const courtNo = await this.freeCourt(tx, pitch, dto.startAt, now);
        return tx.booking.create({
          data: {
            code,
            pitchId: pitch.id,
            teamId: me.teamId,
            createdById: me.userId,
            courtNo,
            startAt: dto.startAt,
            endAt,
            status: 'held',
            price: BigInt(price),
            deposit: BigInt(Math.ceil((price + extraAmount) * 0.3)),
            transferCode: code.replace('SC-', 'SC7'),
            services,
            extraAmount: BigInt(extraAmount),
            note: dto.note || null,
            heldUntil: new Date(now.getTime() + HOLD_MS),
            slotKey: slotKeyOf(pitch.id, courtNo, dto.startAt),
          },
          include: bookingInclude,
        });
      }),
    );
    await this.scheduleExpiry(created.id, created.heldUntil ?? now, now);
    return (await this.toDtos([created]))[0];
  }

  /** Xác nhận đặt sân (trả tại sân): vào lịch đội và báo thành viên. */
  async confirm(me: TeamMembership, bookingId: string): Promise<BookingDto> {
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const b = await this.findOwn(tx, me.teamId, bookingId);
      if (b.status === 'confirmed') return { booking: b, notes: [] };
      if (b.status === 'cancelled') {
        throw this.conflict('booking_cancelled', 'Lượt đặt này đã bị huỷ');
      }
      if (!b.heldUntil || b.heldUntil <= now) {
        // Không ghi gì ở đây (throw sẽ rollback): sân tự coi là trống, worker/lượt giữ sau sẽ dọn
        throw new AppError(
          HttpStatus.CONFLICT,
          'hold_expired',
          'Đã hết thời gian giữ chỗ. Chọn lại khung giờ.',
        );
      }
      const { count } = await tx.booking.updateMany({
        where: { id: b.id, status: 'held', heldUntil: { gt: now } },
        data: { status: 'confirmed', heldUntil: null, confirmedAt: now },
      });
      if (count === 0) {
        throw this.conflict('hold_expired', 'Đã hết thời gian giữ chỗ.');
      }
      const event = await tx.event.create({
        data: {
          teamId: b.teamId,
          kind: 'other',
          title: `Đá tại ${b.pitch.name}`,
          startAt: b.startAt,
          endAt: b.endAt,
          location: `${b.pitch.name}, sân số ${b.courtNo}`,
          createdById: me.userId,
          bookingId: b.id,
        },
      });
      const notes = await writeNotifications(tx, {
        userIds: await teamMemberIds(tx, b.teamId, me.userId),
        type: 'booking.confirmed',
        category: 'booking',
        title: `Đã đặt sân ${b.pitch.name}, sân số ${b.courtNo}`,
        body: `${vnShort(b.startAt)} · Điểm danh đã mở`,
        payload: { teamId: b.teamId, bookingId: b.id, eventId: event.id },
      });
      return { booking: await this.reload(tx, b.id), notes };
    });
    this.realtime.toTeam(me.teamId, 'events.changed', {});
    await this.notifications.dispatch(result.notes);
    return (await this.toDtos([result.booking]))[0];
  }

  async claimDeposit(me: TeamMembership, bookingId: string): Promise<BookingDto> {
    const now = new Date();
    const booking = await this.prisma.$transaction(async (tx) => {
      const b = await this.findOwn(tx, me.teamId, bookingId);
      if (b.status === 'deposit_claimed') return b;
      if (b.status !== 'held' || !b.heldUntil || b.heldUntil <= now) {
        throw this.conflict('hold_expired', 'Lượt giữ chỗ đã hết hạn hoặc không thể yêu cầu cọc');
      }
      await tx.booking.update({ where: { id: b.id }, data: { status: 'deposit_claimed' } });
      return this.reload(tx, b.id);
    });
    return (await this.toDtos([booking]))[0];
  }

  /** Huỷ giữ chỗ hoặc lượt đặt. Không huỷ được khi đã gắn với kèo. */
  async cancel(me: TeamMembership, bookingId: string): Promise<BookingDto> {
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const b = await this.findOwn(tx, me.teamId, bookingId);
      if (b.status === 'cancelled') return { booking: b, notes: [] };
      this.assertChangeable(b, now);
      await tx.booking.update({
        where: { id: b.id },
        data: {
          status: 'cancelled',
          slotKey: null,
          heldUntil: null,
          cancelledAt: now,
        },
      });
      await tx.event.deleteMany({ where: { bookingId: b.id } });
      const notes =
        b.status === 'confirmed'
          ? await writeNotifications(tx, {
              userIds: await teamMemberIds(tx, b.teamId, me.userId),
              type: 'booking.cancelled',
              category: 'booking',
              title: `Đã huỷ đặt sân ${b.pitch.name}`,
              body: vnShort(b.startAt),
              payload: { teamId: b.teamId, bookingId: b.id },
            })
          : [];
      return { booking: await this.reload(tx, b.id), notes };
    });
    this.realtime.toTeam(me.teamId, 'events.changed', {});
    await this.notifications.dispatch(result.notes);
    return (await this.toDtos([result.booking]))[0];
  }

  /** Đổi sang khung giờ khác của cùng sân (giữ nguyên mã). */
  async reschedule(
    me: TeamMembership,
    bookingId: string,
    startAt: Date,
  ): Promise<BookingDto> {
    const now = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      const b = await this.findOwn(tx, me.teamId, bookingId);
      if (b.status !== 'confirmed') {
        throw this.conflict(
          'not_confirmed',
          'Chỉ đổi giờ được lượt đã xác nhận',
        );
      }
      this.assertChangeable(b, now);
      if (startAt.getTime() === b.startAt.getTime()) {
        throw this.bad('same_slot', 'Bạn đang chọn đúng khung giờ hiện tại');
      }
      const pitch = await tx.pitch.findUniqueOrThrow({
        where: { id: b.pitchId },
        select: { id: true, courtsCount: true, slotMinutes: true, slots: true },
      });
      const price = this.priceOf(pitch.slots, startAt, now);
      const endAt = new Date(startAt.getTime() + pitch.slotMinutes * 60_000);
      await this.lockSlot(tx, pitch.id, startAt);
      const courtNo = await this.freeCourt(tx, pitch, startAt, now);
      await tx.booking.update({
        where: { id: b.id },
        data: {
          startAt,
          endAt,
          courtNo,
          price: BigInt(price),
          slotKey: slotKeyOf(pitch.id, courtNo, startAt),
        },
      });
      await tx.event.updateMany({
        where: { bookingId: b.id },
        data: {
          startAt,
          endAt,
          location: `${b.pitch.name}, sân số ${courtNo}`,
        },
      });
      const notes = await writeNotifications(tx, {
        userIds: await teamMemberIds(tx, b.teamId, me.userId),
        type: 'booking.rescheduled',
        category: 'booking',
        title: `Đã đổi giờ đặt sân ${b.pitch.name}`,
        body: `${vnShort(b.startAt)} → ${vnShort(startAt)}`,
        payload: {
          teamId: b.teamId,
          bookingId: b.id,
          eventId: b.event?.id,
        },
      });
      return { booking: await this.reload(tx, b.id), notes };
    });
    this.realtime.toTeam(me.teamId, 'events.changed', {});
    await this.notifications.dispatch(result.notes);
    return (await this.toDtos([result.booking]))[0];
  }

  async get(me: TeamMembership, bookingId: string): Promise<BookingDto> {
    const b = await this.findOwn(this.prisma, me.teamId, bookingId);
    return (await this.toDtos([b]))[0];
  }

  /** Lượt đặt của đội: sắp tới (đã xác nhận hoặc đang giữ) hoặc đã qua. */
  async list(me: TeamMembership, q: ListBookingsQuery): Promise<BookingDto[]> {
    const now = new Date();
    const upcoming = (q.scope ?? 'upcoming') === 'upcoming';
    const rows = await this.prisma.booking.findMany({
      where: {
        teamId: me.teamId,
        ...(upcoming
          ? { endAt: { gte: now }, ...active(now) }
          : { endAt: { lt: now }, status: 'confirmed' }),
      },
      include: bookingInclude,
      orderBy: { startAt: upcoming ? 'asc' : 'desc' },
      take: q.limit ?? 20,
    });
    return this.toDtos(rows);
  }

  // ---------- nội bộ ----------

  /** Giờ bắt đầu hợp lệ (đúng khung giờ mẫu, tương lai, trong 30 ngày) → giá. */
  private priceOf(slots: unknown, startAt: Date, now: Date): number {
    const t = matchTemplate(parseSlots(slots), startAt);
    if (!t) {
      throw this.bad('invalid_slot', 'Khung giờ này không có ở sân đã chọn');
    }
    if (startAt <= now) throw this.bad('invalid_slot', 'Khung giờ này đã qua');
    if (startAt.getTime() - now.getTime() > MAX_AHEAD_MS) {
      throw this.bad('invalid_slot', 'Chỉ đặt sân trong vòng 30 ngày tới');
    }
    return t.price;
  }

  /** Hai người cùng giữ một khung giờ không được chạy chồng nhau. */
  private async lockSlot(tx: Tx, pitchId: string, startAt: Date) {
    await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtext(${`slot:${pitchId}:${startAt.toISOString()}`}))`;
  }

  /** Nhả các lượt giữ hết hạn của khung giờ rồi chọn sân số nhỏ nhất còn trống. */
  private async freeCourt(
    tx: Tx,
    pitch: { id: string; courtsCount: number },
    startAt: Date,
    now: Date,
  ): Promise<number> {
    await tx.booking.updateMany({
      where: {
        pitchId: pitch.id,
        startAt,
        status: 'held',
        heldUntil: { lte: now },
      },
      data: {
        status: 'cancelled',
        slotKey: null,
        heldUntil: null,
        cancelledAt: now,
      },
    });
    const taken = new Set(
      (
        await tx.booking.findMany({
          where: { pitchId: pitch.id, startAt, slotKey: { not: null } },
          select: { courtNo: true },
        })
      ).map((b) => b.courtNo),
    );
    for (let n = 1; n <= pitch.courtsCount; n++) {
      if (!taken.has(n)) return n;
    }
    throw this.conflict(
      'slot_full',
      'Khung giờ này vừa hết sân. Chọn giờ khác.',
    );
  }

  /** Thử lại với mã khác nếu trùng mã đặt sân (hiếm). */
  private async withCodeRetry<T>(
    run: (code: string) => Promise<T>,
  ): Promise<T> {
    for (let i = 0; ; i++) {
      try {
        return await run(newBookingCode());
      } catch (e) {
        if (i < 4 && isUniqueViolation(e, 'code')) continue;
        if (isUniqueViolation(e, 'slot_key')) {
          throw this.conflict(
            'slot_full',
            'Khung giờ này vừa hết sân. Chọn giờ khác.',
          );
        }
        throw e;
      }
    }
  }

  private assertChangeable(b: BookingRow, now: Date) {
    if (b.startAt <= now) {
      throw this.conflict(
        'booking_started',
        'Đã tới giờ đá, không thể thay đổi',
      );
    }
    if (b.post) {
      throw this.conflict(
        'booking_has_post',
        'Sân đang gắn với một kèo. Đóng kèo hoặc huỷ trận trước.',
      );
    }
  }

  private async findOwn(
    db: Pick<Prisma.TransactionClient, 'booking'>,
    teamId: string,
    bookingId: string,
  ): Promise<BookingRow> {
    const b = await db.booking.findFirst({
      where: { id: bookingId, teamId },
      include: bookingInclude,
    });
    if (!b) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'booking_not_found',
        'Không tìm thấy lượt đặt sân',
      );
    }
    return b;
  }

  private reload(tx: Tx, id: string): Promise<BookingRow> {
    return tx.booking.findUniqueOrThrow({
      where: { id },
      include: bookingInclude,
    });
  }

  /** Thêm toạ độ sân (cột geography không đọc được qua Prisma). */
  async toDtos(rows: BookingRow[]): Promise<BookingDto[]> {
    if (rows.length === 0) return [];
    const ids = [...new Set(rows.map((r) => r.pitchId))];
    const coords = await this.prisma.$queryRaw<
      { id: string; lat: number; lng: number }[]
    >`SELECT id::text AS id, ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng
      FROM pitches WHERE id IN (${Prisma.join(ids.map((i) => Prisma.sql`${i}::uuid`))})`;
    const byId = new Map(coords.map((c) => [c.id, c]));
    const now = new Date();
    return rows.map((r) => ({
      id: r.id,
      code: r.code,
      status: r.status,
      teamId: r.teamId,
      pitch: {
        ...r.pitch,
        lat: byId.get(r.pitchId)?.lat ?? 0,
        lng: byId.get(r.pitchId)?.lng ?? 0,
      },
      courtNo: r.courtNo,
      startAt: r.startAt,
      endAt: r.endAt,
      price: toMoney(r.price),
      deposit: toMoney(r.deposit),
      transferCode: r.transferCode,
      services: Array.isArray(r.services) ? r.services.filter((service): service is string => typeof service === 'string') : [],
      extraAmount: toMoney(r.extraAmount),
      note: r.note,
      heldUntil: r.heldUntil,
      postId: r.post?.id ?? null,
      eventId: r.event?.id ?? null,
      canChange: r.status !== 'cancelled' && r.startAt > now && !r.post,
      createdAt: r.createdAt,
    }));
  }

  private async scheduleExpiry(id: string, heldUntil: Date, now: Date) {
    try {
      await this.queue.add(
        Jobs.bookingExpire,
        { bookingId: id },
        {
          delay: Math.max(0, heldUntil.getTime() - now.getTime()) + 1000,
          jobId: `booking-expire-${id}`,
          removeOnComplete: true,
          removeOnFail: 100,
        },
      );
    } catch (e) {
      // Lượt giữ hết hạn vẫn được tính đúng khi đọc; job chỉ dọn dữ liệu
      this.logger.warn(`Không hẹn được job nhả chỗ: ${String(e)}`);
    }
  }

  private bad(code: string, message: string) {
    return new AppError(HttpStatus.BAD_REQUEST, code, message);
  }

  private conflict(code: string, message: string) {
    return new AppError(HttpStatus.CONFLICT, code, message);
  }

  private pitchNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'pitch_not_found',
      'Không tìm thấy sân',
    );
  }
}
