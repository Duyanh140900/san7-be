const VN_OFFSET_MS = 7 * 3_600_000;
const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

const pad = (n: number) => String(n).padStart(2, '0');

/** "T7 22/11 · 19:00" theo giờ Việt Nam (dùng trong nội dung thông báo). */
export function vnShort(d: Date): string {
  const vn = new Date(d.getTime() + VN_OFFSET_MS);
  return `${WEEKDAYS[vn.getUTCDay()]} ${pad(vn.getUTCDate())}/${pad(vn.getUTCMonth() + 1)} · ${pad(vn.getUTCHours())}:${pad(vn.getUTCMinutes())}`;
}

/** "2026-11-22" theo giờ Việt Nam. */
export function vnDate(d: Date): string {
  const vn = new Date(d.getTime() + VN_OFFSET_MS);
  return `${vn.getUTCFullYear()}-${pad(vn.getUTCMonth() + 1)}-${pad(vn.getUTCDate())}`;
}

/** "19:00" theo giờ Việt Nam. */
export function vnHm(d: Date): string {
  const vn = new Date(d.getTime() + VN_OFFSET_MS);
  return `${pad(vn.getUTCHours())}:${pad(vn.getUTCMinutes())}`;
}

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;
const HM_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;

export const isHm = (s: string) => HM_RE.test(s);

/** "YYYY-MM-DD" hợp lệ (đúng lịch) hay không. */
export function isVnDate(s: string): boolean {
  const m = DATE_RE.exec(s);
  if (!m) return false;
  const [y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const t = new Date(Date.UTC(y, mo - 1, d));
  return (
    t.getUTCFullYear() === y &&
    t.getUTCMonth() === mo - 1 &&
    t.getUTCDate() === d
  );
}

/** Ngày giờ VN ("2026-11-22", "19:00") → thời điểm UTC. */
export function vnToUtc(date: string, hm: string): Date {
  const [y, mo, d] = date.split('-').map(Number);
  const [h, mi] = hm.split(':').map(Number);
  return new Date(Date.UTC(y, mo - 1, d, h, mi) - VN_OFFSET_MS);
}
