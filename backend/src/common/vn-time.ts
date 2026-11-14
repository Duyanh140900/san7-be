const VN_OFFSET_MS = 7 * 3_600_000;
const WEEKDAYS = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

const pad = (n: number) => String(n).padStart(2, '0');

/** "T7 22/11 · 19:00" theo giờ Việt Nam (dùng trong nội dung thông báo). */
export function vnShort(d: Date): string {
  const vn = new Date(d.getTime() + VN_OFFSET_MS);
  return `${WEEKDAYS[vn.getUTCDay()]} ${pad(vn.getUTCDate())}/${pad(vn.getUTCMonth() + 1)} · ${pad(vn.getUTCHours())}:${pad(vn.getUTCMinutes())}`;
}
