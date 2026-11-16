import { isVnDate, vnDate, vnHm, vnToUtc } from '../common/vn-time.js';
import {
  buildSlots,
  matchTemplate,
  parseSlots,
  slotMapKey,
} from './pitch-slots.js';

describe('giờ Việt Nam', () => {
  it('đổi qua lại giữa UTC và giờ VN, kể cả qua nửa đêm', () => {
    const t = vnToUtc('2026-11-22', '19:00');
    expect(t.toISOString()).toBe('2026-11-22T12:00:00.000Z');
    expect(vnDate(t)).toBe('2026-11-22');
    expect(vnHm(t)).toBe('19:00');
    // 00:30 giờ VN ngày 23 là 17:30 UTC ngày 22
    const late = vnToUtc('2026-11-23', '00:30');
    expect(late.toISOString()).toBe('2026-11-22T17:30:00.000Z');
    expect(vnDate(late)).toBe('2026-11-23');
  });

  it('kiểm tra ngày đúng lịch', () => {
    expect(isVnDate('2026-11-22')).toBe(true);
    expect(isVnDate('2026-02-30')).toBe(false);
    expect(isVnDate('22/11/2026')).toBe(false);
  });
});

describe('parseSlots', () => {
  it('bỏ phần tử sai định dạng và sắp theo giờ', () => {
    const r = parseSlots([
      { start: '19:00', price: 600000 },
      { start: '25:00', price: 1 },
      { start: '06:00', price: 300000 },
      { start: '07:30', price: 1.5 },
      { start: '08:00' },
      'x',
    ]);
    expect(r.map((s) => s.start)).toEqual(['06:00', '19:00']);
    expect(parseSlots(null)).toEqual([]);
  });
});

describe('matchTemplate', () => {
  const tpl = [
    { start: '06:00', price: 300000 },
    { start: '19:00', price: 600000 },
  ];
  it('chỉ nhận đúng giờ bắt đầu của khung mẫu', () => {
    expect(matchTemplate(tpl, vnToUtc('2026-11-22', '19:00'))?.price).toBe(
      600000,
    );
    expect(matchTemplate(tpl, vnToUtc('2026-11-22', '19:30'))).toBeNull();
    // lệch vài giây không được coi là cùng khung
    const off = new Date(vnToUtc('2026-11-22', '19:00').getTime() + 5000);
    expect(matchTemplate(tpl, off)).toBeNull();
  });
});

describe('buildSlots', () => {
  const now = new Date('2026-11-22T05:00:00Z'); // 12:00 giờ VN
  const tpl = [
    { start: '07:30', price: 300000 },
    { start: '19:00', price: 600000 },
    { start: '20:30', price: 600000 },
  ];

  it('tính số sân trống, khung đã qua và khung kín', () => {
    const taken = new Map<string, number>([
      [slotMapKey('p1', vnToUtc('2026-11-22', '19:00')), 2],
      [slotMapKey('p1', vnToUtc('2026-11-22', '20:30')), 3],
    ]);
    const s = buildSlots(tpl, 90, 3, '2026-11-22', 'p1', taken, now);
    expect(s.map((x) => [x.free, x.available])).toEqual([
      [3, false], // 07:30 đã qua dù còn sân
      [1, true],
      [0, false],
    ]);
    expect(s[1].endAt.getTime() - s[1].startAt.getTime()).toBe(90 * 60_000);
    expect(s[1].total).toBe(3);
  });

  it('không lẫn lượt đặt của sân khác', () => {
    const taken = new Map([
      [slotMapKey('other', vnToUtc('2026-11-22', '19:00')), 3],
    ]);
    const s = buildSlots(tpl, 90, 3, '2026-11-22', 'p1', taken, now);
    expect(s[1].free).toBe(3);
  });
});
