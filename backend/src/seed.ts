/**
 * Seed sân bóng mẫu (Hà Nội). Chạy lại nhiều lần an toàn: cập nhật theo `slug`.
 *   Ngoài Docker:  npm run build && npm run seed
 *   Trong Docker:  docker compose exec api node dist/seed.js
 * Đây là dữ liệu MẪU để chạy thử, thay bằng dữ liệu sân thật trước khi ra mắt.
 */
import { PrismaPg } from '@prisma/adapter-pg';
import { config } from 'dotenv';
import { PrismaClient } from './generated/prisma/client.js';

config({ path: '../.env', quiet: true });

interface SeedPitch {
  slug: string;
  name: string;
  district: string;
  address: string;
  lat: number;
  lng: number;
  courts: number;
  /** giá khung giờ thường; khung 17:00–22:00 cao hơn */
  base: number;
  amenities: string[];
}

const TIMES = [
  '06:00',
  '07:30',
  '14:00',
  '15:30',
  '17:00',
  '18:30',
  '20:00',
  '21:30',
];
/** Khung giờ vàng (sau giờ làm) giá cao hơn. */
const PEAK = new Set(['17:00', '18:30', '20:00']);
const ALL = ['light', 'new_turf', 'parking', 'water', 'locker'];

const PITCHES: SeedPitch[] = [
  {
    slug: 'ha-dong-arena',
    name: 'Hà Đông Arena',
    district: 'Hà Đông',
    address: 'Phường Văn Quán, Hà Đông',
    lat: 20.981,
    lng: 105.789,
    courts: 4,
    base: 350_000,
    amenities: ALL,
  },
  {
    slug: 'san-phuc-la',
    name: 'Sân bóng Phúc La',
    district: 'Hà Đông',
    address: 'Phường Phúc La, Hà Đông',
    lat: 20.968,
    lng: 105.794,
    courts: 3,
    base: 300_000,
    amenities: ['light', 'parking', 'water'],
  },
  {
    slug: 'kim-giang',
    name: 'Sân Kim Giang',
    district: 'Thanh Xuân',
    address: 'Đường Kim Giang, Thanh Xuân',
    lat: 20.989,
    lng: 105.81,
    courts: 2,
    base: 300_000,
    amenities: ['light', 'parking'],
  },
  {
    slug: 'van-quan',
    name: 'Sân Văn Quán',
    district: 'Hà Đông',
    address: 'Phường Văn Quán, Hà Đông',
    lat: 20.978,
    lng: 105.787,
    courts: 2,
    base: 280_000,
    amenities: ['light', 'water'],
  },
  {
    slug: 'thanh-xuan-stadium',
    name: 'Thanh Xuân Stadium',
    district: 'Thanh Xuân',
    address: 'Nguyễn Trãi, Thanh Xuân',
    lat: 21.0,
    lng: 105.807,
    courts: 4,
    base: 380_000,
    amenities: ALL,
  },
  {
    slug: 'cau-giay-sports',
    name: 'Cầu Giấy Sports',
    district: 'Cầu Giấy',
    address: 'Dịch Vọng, Cầu Giấy',
    lat: 21.036,
    lng: 105.79,
    courts: 3,
    base: 400_000,
    amenities: ALL,
  },
  {
    slug: 'my-dinh-arena',
    name: 'Mỹ Đình Arena',
    district: 'Nam Từ Liêm',
    address: 'Mỹ Đình, Nam Từ Liêm',
    lat: 21.027,
    lng: 105.766,
    courts: 5,
    base: 420_000,
    amenities: ALL,
  },
  {
    slug: 'trung-kinh',
    name: 'Trung Kính Football',
    district: 'Cầu Giấy',
    address: 'Trung Kính, Cầu Giấy',
    lat: 21.01,
    lng: 105.796,
    courts: 3,
    base: 360_000,
    amenities: ['light', 'new_turf', 'parking', 'water'],
  },
  {
    slug: 'hoang-mai',
    name: 'Hoàng Mai Pitch',
    district: 'Hoàng Mai',
    address: 'Giáp Bát, Hoàng Mai',
    lat: 20.974,
    lng: 105.856,
    courts: 3,
    base: 290_000,
    amenities: ['light', 'parking', 'locker'],
  },
  {
    slug: 'long-bien-arena',
    name: 'Long Biên Arena',
    district: 'Long Biên',
    address: 'Ngọc Lâm, Long Biên',
    lat: 21.045,
    lng: 105.89,
    courts: 4,
    base: 320_000,
    amenities: ['light', 'new_turf', 'parking', 'water'],
  },
  {
    slug: 'tay-ho',
    name: 'Sân Tây Hồ',
    district: 'Tây Hồ',
    address: 'Quảng An, Tây Hồ',
    lat: 21.07,
    lng: 105.82,
    courts: 2,
    base: 450_000,
    amenities: ALL,
  },
  {
    slug: 'dong-da',
    name: 'Sân Đống Đa',
    district: 'Đống Đa',
    address: 'Láng Hạ, Đống Đa',
    lat: 21.015,
    lng: 105.825,
    courts: 2,
    base: 400_000,
    amenities: ['light', 'water', 'locker'],
  },
];

const slotsOf = (p: SeedPitch) =>
  TIMES.map((start) => ({
    start,
    price: PEAK.has(start)
      ? p.base + 150_000
      : start === '21:30'
        ? p.base + 50_000
        : p.base,
  }));

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

try {
  for (const p of PITCHES) {
    await prisma.$executeRaw`
      INSERT INTO pitches (slug, name, district, address, location, courts_count, slot_minutes, slots, amenities)
      VALUES (${p.slug}, ${p.name}, ${p.district}, ${p.address},
              ST_SetSRID(ST_MakePoint(${p.lng}, ${p.lat}), 4326)::geography,
              ${p.courts}, 90, ${JSON.stringify(slotsOf(p))}::jsonb, ${p.amenities}::text[])
      ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name, district = EXCLUDED.district, address = EXCLUDED.address,
        location = EXCLUDED.location, courts_count = EXCLUDED.courts_count,
        slot_minutes = EXCLUDED.slot_minutes, slots = EXCLUDED.slots,
        amenities = EXCLUDED.amenities`;
  }
  console.log(`Đã seed ${PITCHES.length} sân mẫu`);
} finally {
  await prisma.$disconnect();
}
