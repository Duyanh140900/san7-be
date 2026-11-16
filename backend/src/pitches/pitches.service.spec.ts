import { vnDate, vnToUtc } from '../common/vn-time.js';
import { Prisma } from '../generated/prisma/client.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { slotMapKey } from './pitch-slots.js';
import { likeEscape, PitchesService } from './pitches.service.js';

const DAY = 86_400_000;
/** Ngày mai theo giờ VN: mọi khung đều ở tương lai nên không bị coi là "đã qua". */
const tomorrow = vnDate(new Date(Date.now() + DAY));

const row = (over: Record<string, unknown> = {}) => ({
  id: 'p1',
  name: 'Hà Đông Arena',
  district: 'Hà Đông',
  address: 'Văn Quán',
  courtsCount: 2,
  slotMinutes: 90,
  slots: [
    { start: '06:00', price: 300_000 },
    { start: '19:00', price: 600_000 },
  ],
  amenities: ['light'],
  phone: null,
  lat: 20.98,
  lng: 105.79,
  distanceM: null,
  ...over,
});

function setup(
  rows: ReturnType<typeof row>[],
  taken: { pitchId: string; startAt: Date; n: number }[] = [],
) {
  const prisma = {
    $queryRaw: vi.fn().mockResolvedValue(rows),
    booking: {
      groupBy: vi.fn().mockResolvedValue(
        taken.map((t) => ({
          pitchId: t.pitchId,
          startAt: t.startAt,
          _count: { _all: t.n },
        })),
      ),
    },
  };
  return {
    service: new PitchesService(prisma as unknown as PrismaService),
    prisma,
  };
}

/** Các giá trị tham số của câu SQL đã gửi (Prisma gộp cả đoạn SQL lồng nhau). */
function sqlValues(call: unknown[]): unknown[] {
  return call
    .slice(1)
    .flatMap((f) => (f instanceof Prisma.Sql ? f.values : [f]));
}

describe('likeEscape', () => {
  it('vô hiệu ký tự đặc biệt của ILIKE', () => {
    expect(likeEscape('50%_off')).toBe('50\\%\\_off');
    expect(likeEscape('a\\b')).toBe('a\\\\b');
    expect(likeEscape('Hà Đông')).toBe('Hà Đông');
  });
});

describe('PitchesService.list', () => {
  it('tính khung còn trống theo lượt đặt, số khung trống và giá thấp nhất', async () => {
    const full = vnToUtc(tomorrow, '19:00');
    const { service, prisma } = setup(
      [row({ distanceM: 350.4 })],
      [{ pitchId: 'p1', startAt: full, n: 2 }],
    );
    const { items } = await service.list({ date: tomorrow });
    const p = items[0];
    expect(p.slots.map((s) => [s.free, s.available])).toEqual([
      [2, true],
      [0, false],
    ]);
    expect(p.freeSlots).toBe(1);
    expect(p.minPrice).toBe(300_000);
    expect(p.distanceM).toBe(350);
    // đếm lượt đặt một lần cho cả danh sách, chỉ trong ngày được chọn
    expect(prisma.booking.groupBy).toHaveBeenCalledTimes(1);
    const where = prisma.booking.groupBy.mock.calls[0][0].where;
    expect(where.startAt).toEqual({
      gte: vnToUtc(tomorrow, '00:00'),
      lte: vnToUtc(tomorrow, '23:59'),
    });
  });

  it('không có vị trí thì không có khoảng cách', async () => {
    const { service } = setup([row()]);
    const { items } = await service.list({ date: tomorrow });
    expect(items[0].distanceM).toBeUndefined();
  });

  it('lọc theo giờ: bỏ sân đã kín đúng khung đó', async () => {
    const slot = vnToUtc(tomorrow, '19:00');
    const rows = [row(), row({ id: 'p2', name: 'Sân B' })];
    const { service } = setup(rows, [{ pitchId: 'p1', startAt: slot, n: 2 }]);
    const r = await service.list({ date: tomorrow, at: '19:00' });
    expect(r.items.map((p) => p.id)).toEqual(['p2']);
    // khung khác vẫn còn ở cả hai sân
    const r2 = await setup(rows, [
      { pitchId: 'p1', startAt: slot, n: 2 },
    ]).service.list({ date: tomorrow, at: '06:00' });
    expect(r2.items).toHaveLength(2);
  });

  it('giới hạn số kết quả sau khi lọc', async () => {
    const { service } = setup([row(), row({ id: 'p2' }), row({ id: 'p3' })]);
    const r = await service.list({ date: tomorrow, limit: 2 });
    expect(r.items).toHaveLength(2);
  });

  it('từ khoá được vô hiệu ký tự đặc biệt trước khi gửi vào SQL', async () => {
    const { service, prisma } = setup([]);
    await service.list({ date: tomorrow, q: '50%_x', amenity: 'light' });
    const values = sqlValues(prisma.$queryRaw.mock.calls[0]);
    expect(values).toContain('%50\\%\\_x%');
    expect(values).toContain('light');
  });

  it('chỉ lọc theo bán kính khi đủ cả hai toạ độ', async () => {
    const { service, prisma } = setup([]);
    await service.list({ date: tomorrow, lat: 20.98 });
    const noPos = sqlValues(prisma.$queryRaw.mock.calls[0]);
    expect(noPos).not.toContain(15_000);
    await service.list({ date: tomorrow, lat: 20.98, lng: 105.79 });
    const withPos = sqlValues(prisma.$queryRaw.mock.calls[1]);
    expect(withPos).toContain(15_000);
    await service.list({
      date: tomorrow,
      lat: 20.98,
      lng: 105.79,
      radiusKm: 1,
    });
    expect(sqlValues(prisma.$queryRaw.mock.calls[2])).toContain(1_000);
  });

  it('ngày đã qua hoặc không hợp lệ → 400 invalid_date', async () => {
    const { service, prisma } = setup([]);
    for (const date of ['2020-01-01', '2026-02-30', 'abc']) {
      await expect(service.list({ date })).rejects.toMatchObject({
        status: 400,
        response: { code: 'invalid_date' },
      });
    }
    expect(prisma.$queryRaw).not.toHaveBeenCalled();
  });

  it('mặc định là hôm nay', async () => {
    const { service } = setup([row()]);
    const { items } = await service.list({});
    expect(items[0].date).toBe(vnDate(new Date()));
  });
});

describe('PitchesService.detail', () => {
  it('trả sân kèm khung giờ của ngày chọn', async () => {
    const { service } = setup([row()]);
    const p = await service.detail('p1', { date: tomorrow });
    expect(p.date).toBe(tomorrow);
    expect(p.slots).toHaveLength(2);
    expect(p.slots[0].startAt).toEqual(vnToUtc(tomorrow, '06:00'));
  });

  it('không tìm thấy → 404', async () => {
    const { service } = setup([]);
    await expect(service.detail('x', {})).rejects.toMatchObject({
      status: 404,
      response: { code: 'pitch_not_found' },
    });
  });
});

describe('slotMapKey', () => {
  it('khác sân hoặc khác giờ thì khác khoá', () => {
    const t = new Date('2026-11-22T12:00:00Z');
    expect(slotMapKey('a', t)).not.toBe(slotMapKey('b', t));
    expect(slotMapKey('a', t)).not.toBe(
      slotMapKey('a', new Date(t.getTime() + 1)),
    );
  });
});
