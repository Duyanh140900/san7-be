import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { isVnDate, vnDate, vnToUtc } from '../common/vn-time.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { countTaken } from './pitch-availability.js';
import { buildSlots, parseSlots } from './pitch-slots.js';
import type {
  PitchDetailQuery,
  PitchDto,
  FreePitchSlotDto,
  FreePitchSlotsQuery,
  CreatePitchReviewDto,
  PitchReviewDto,
  PitchListDto,
  PitchListQuery,
} from './pitches.dto.js';

interface PitchRow {
  id: string;
  name: string;
  district: string;
  address: string;
  courtsCount: number;
  slotMinutes: number;
  slots: unknown;
  amenities: string[];
  phone: string | null;
  lat: number;
  lng: number;
  distanceM: number | null;
}

const DEFAULT_RADIUS_KM = 15;

/** Đổi ký tự đặc biệt của ILIKE thành ký tự thường. */
export const likeEscape = (s: string) => s.replace(/[\\%_]/g, (c) => `\\${c}`);

@Injectable()
export class PitchesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(q: PitchListQuery): Promise<PitchListDto> {
    const now = new Date();
    const date = this.resolveDate(q.date, now);
    const pos = this.position(q.lat, q.lng);

    const conds: Prisma.Sql[] = [];
    if (pos) {
      conds.push(
        Prisma.sql`ST_DWithin(location, ST_SetSRID(ST_MakePoint(${pos.lng}, ${pos.lat}), 4326)::geography, ${(q.radiusKm ?? DEFAULT_RADIUS_KM) * 1000})`,
      );
    }
    if (q.q) {
      const like = `%${likeEscape(q.q)}%`;
      conds.push(
        Prisma.sql`(name ILIKE ${like} OR district ILIKE ${like} OR address ILIKE ${like})`,
      );
    }
    if (q.amenity) {
      conds.push(Prisma.sql`amenities @> ARRAY[${q.amenity}]::text[]`);
    }
    const rows = await this.query(conds, pos, 100);
    const items = await this.toDtos(rows, date, now);
    const filtered = q.at
      ? items.filter((p) =>
          p.slots.some(
            (s) =>
              s.available &&
              s.startAt.getTime() === vnToUtc(date, q.at!).getTime(),
          ),
        )
      : items;
    return { items: filtered.slice(0, q.limit ?? 30) };
  }

  async detail(pitchId: string, q: PitchDetailQuery): Promise<PitchDto> {
    const now = new Date();
    const date = this.resolveDate(q.date, now);
    const rows = await this.query(
      [Prisma.sql`id = ${pitchId}::uuid`],
      this.position(q.lat, q.lng),
      1,
    );
    if (rows.length === 0) {
      throw new AppError(
        HttpStatus.NOT_FOUND,
        'pitch_not_found',
        'Không tìm thấy sân',
      );
    }
    return (await this.toDtos(rows, date, now))[0];
  }

  async freeSlots(q: FreePitchSlotsQuery): Promise<FreePitchSlotDto[]> {
    const now = new Date();
    const from = q.from && q.from > now ? q.from : now;
    const to = q.to ?? vnToUtc(vnDate(now), '23:59');
    if (to <= from) throw new AppError(HttpStatus.BAD_REQUEST, 'invalid_time_range', 'Khoảng thời gian không hợp lệ');
    const pos = this.position(q.lat, q.lng);
    const rows = await this.query([], pos, 100);
    const dates = [...new Set([vnDate(from), vnDate(to)])];
    const all = await Promise.all(dates.map((date) => this.toDtos(rows, date, now)));
    const ratingRows = await this.prisma.pitchReview.groupBy({ by: ['pitchId'], _avg: { stars: true } });
    const ratings = new Map(ratingRows.map((row) => [row.pitchId, Number(row._avg.stars ?? 0)]));
    return rows.flatMap((row) => {
      const slot = all.flatMap((items) => items.find((item) => item.id === row.id)?.slots ?? [])
        .filter((item) => item.available && item.startAt >= from && item.startAt <= to)
        .sort((a, b) => a.startAt.getTime() - b.startAt.getTime())[0];
      return slot ? [{ pitchId: row.id, name: row.name, distanceKm: row.distanceM === null ? undefined : Number((row.distanceM / 1000).toFixed(2)), rating: Number((ratings.get(row.id) ?? 0).toFixed(1)), slotStart: slot.startAt }] : [];
    }).sort((a, b) => a.slotStart.getTime() - b.slotStart.getTime()).slice(0, 12);
  }

  async listReviews(pitchId: string): Promise<PitchReviewDto[]> {
    return this.prisma.pitchReview.findMany({ where: { pitchId }, orderBy: { createdAt: 'desc' }, take: 50 });
  }

  async createReview(userId: string, pitchId: string, dto: CreatePitchReviewDto): Promise<PitchReviewDto> {
    const pitch = await this.prisma.pitch.findUnique({ where: { id: pitchId }, select: { id: true } });
    if (!pitch) throw new AppError(HttpStatus.NOT_FOUND, 'pitch_not_found', 'Không tìm thấy sân');
    if (dto.bookingId && !await this.prisma.booking.findFirst({ where: { id: dto.bookingId, pitchId, createdById: userId }, select: { id: true } })) throw new AppError(HttpStatus.FORBIDDEN, 'booking_not_owned', 'Bạn không thể đánh giá lượt đặt này');
    const data = { ...dto, tags: dto.tags ?? [], comment: dto.comment ?? null };
    if (dto.bookingId) return this.prisma.pitchReview.upsert({ where: { pitchId_userId_bookingId: { pitchId, userId, bookingId: dto.bookingId } }, create: { pitchId, userId, ...data }, update: data });
    const existing = await this.prisma.pitchReview.findFirst({ where: { pitchId, userId, bookingId: null }, select: { id: true } });
    return existing ? this.prisma.pitchReview.update({ where: { id: existing.id }, data }) : this.prisma.pitchReview.create({ data: { pitchId, userId, ...data } });
  }

  private resolveDate(date: string | undefined, now: Date): string {
    const today = vnDate(now);
    const d = date ?? today;
    if (!isVnDate(d) || d < today) {
      throw new AppError(
        HttpStatus.BAD_REQUEST,
        'invalid_date',
        'Ngày không hợp lệ hoặc đã qua',
      );
    }
    return d;
  }

  /** Cần đủ cả hai toạ độ mới tính khoảng cách. */
  private position(lat?: number, lng?: number) {
    return lat !== undefined && lng !== undefined ? { lat, lng } : null;
  }

  private query(
    conds: Prisma.Sql[],
    pos: { lat: number; lng: number } | null,
    limit: number,
  ): Promise<PitchRow[]> {
    const distance = pos
      ? Prisma.sql`ST_Distance(location, ST_SetSRID(ST_MakePoint(${pos.lng}, ${pos.lat}), 4326)::geography)`
      : Prisma.sql`NULL::float8`;
    const where = conds.length
      ? Prisma.sql`WHERE ${Prisma.join(conds, ' AND ')}`
      : Prisma.empty;
    return this.prisma.$queryRaw<PitchRow[]>`
      SELECT id::text AS id, name, district, address,
             courts_count AS "courtsCount", slot_minutes AS "slotMinutes",
             slots, amenities, phone,
             ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng,
             ${distance} AS "distanceM"
      FROM pitches
      ${where}
      ORDER BY "distanceM" ASC NULLS LAST, name ASC
      LIMIT ${limit}`;
  }

  private async toDtos(
    rows: PitchRow[],
    date: string,
    now: Date,
  ): Promise<PitchDto[]> {
    const taken = await countTaken(
      this.prisma,
      rows.map((r) => r.id),
      vnToUtc(date, '00:00'),
      vnToUtc(date, '23:59'),
      now,
    );
    return rows.map((r) => {
      const slots = buildSlots(
        parseSlots(r.slots),
        r.slotMinutes,
        r.courtsCount,
        date,
        r.id,
        taken,
        now,
      );
      const open = slots.filter((s) => s.available);
      return {
        id: r.id,
        name: r.name,
        district: r.district,
        address: r.address,
        lat: r.lat,
        lng: r.lng,
        distanceM: r.distanceM === null ? undefined : Math.round(r.distanceM),
        amenities: r.amenities,
        courtsCount: r.courtsCount,
        slotMinutes: r.slotMinutes,
        phone: r.phone,
        date,
        slots,
        freeSlots: open.length,
        minPrice: open.length
          ? Math.min(...open.map((s) => s.price))
          : undefined,
      };
    });
  }
}
