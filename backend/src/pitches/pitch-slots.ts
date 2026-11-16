import { isHm, vnDate, vnHm, vnToUtc } from '../common/vn-time.js';

/** Khung giờ mẫu của một sân (giờ VN), đặt trong cột pitches.slots. */
export interface SlotTemplate {
  start: string;
  price: number;
}

export interface Slot {
  startAt: Date;
  endAt: Date;
  price: number;
  /** số sân còn trống */
  free: number;
  total: number;
  /** còn chỗ và chưa tới giờ */
  available: boolean;
}

/** Đọc cột JSON, bỏ phần tử sai định dạng, sắp theo giờ. */
export function parseSlots(json: unknown): SlotTemplate[] {
  if (!Array.isArray(json)) return [];
  return json
    .filter(
      (s): s is SlotTemplate =>
        typeof s === 'object' &&
        s !== null &&
        typeof (s as SlotTemplate).start === 'string' &&
        isHm((s as SlotTemplate).start) &&
        Number.isInteger((s as SlotTemplate).price) &&
        (s as SlotTemplate).price >= 0,
    )
    .sort((a, b) => a.start.localeCompare(b.start));
}

/** Khoá ghép sân + giờ để đếm lượt đặt: "<pitchId>|<epochMs>". */
export const slotMapKey = (pitchId: string, startAt: Date) =>
  `${pitchId}|${startAt.getTime()}`;

/** Các khung giờ của một sân trong một ngày VN, kèm số sân còn trống. */
export function buildSlots(
  template: SlotTemplate[],
  slotMinutes: number,
  courts: number,
  date: string,
  pitchId: string,
  taken: Map<string, number>,
  now: Date,
): Slot[] {
  return template.map((t) => {
    const startAt = vnToUtc(date, t.start);
    const free = Math.max(
      0,
      courts - (taken.get(slotMapKey(pitchId, startAt)) ?? 0),
    );
    return {
      startAt,
      endAt: new Date(startAt.getTime() + slotMinutes * 60_000),
      price: t.price,
      free,
      total: courts,
      available: free > 0 && startAt > now,
    };
  });
}

/** Giờ bắt đầu có đúng là một khung giờ mẫu của sân không? Trả khung đó. */
export function matchTemplate(
  template: SlotTemplate[],
  startAt: Date,
): SlotTemplate | null {
  const hm = vnHm(startAt);
  const t = template.find((s) => s.start === hm);
  // vnToUtc(vnDate(startAt), hm) loại bỏ trường hợp có giây/mili giây lẻ
  return t && vnToUtc(vnDate(startAt), hm).getTime() === startAt.getTime()
    ? t
    : null;
}
