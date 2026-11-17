import { describe, expect, it } from 'vitest';
import { normalizeOsmPitch } from './import-osm-pitches.js';

describe('normalizeOsmPitch', () => {
  it('chuẩn hoá sân có tên và giữ thông tin liên hệ OSM', () => {
    const pitch = normalizeOsmPitch(
      {
        type: 'way',
        id: 42,
        center: { lat: 21.03, lon: 105.8 },
        tags: {
          name: 'Sân Bóng Cầu Giấy',
          'addr:street': 'Đường Trần Thái Tông',
          'addr:district': 'Cầu Giấy',
          phone: '0900000000',
          opening_hours: '06:00-23:00',
        },
      },
      { displayName: 'Hà Nội' },
    );

    expect(pitch).toMatchObject({
      osmId: 'way/42',
      slug: 'osm-way-42',
      district: 'Cầu Giấy',
      phone: '0900000000',
      openingHours: '06:00-23:00',
    });
  });

  it('bỏ qua phần tử OSM không tên hoặc không có toạ độ', () => {
    expect(normalizeOsmPitch({ type: 'node', id: 1, tags: {} }, { displayName: 'Hà Nội' })).toBeNull();
  });
});
