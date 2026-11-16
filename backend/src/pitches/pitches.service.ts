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
