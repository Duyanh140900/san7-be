/**
 * Nhập sân bóng từ OpenStreetMap/Overpass.
 * Chỉ dùng dữ liệu có giấy phép ODbL: © OpenStreetMap contributors.
 * Mỗi thành phố dùng đúng một request tuần tự; phản hồi được cache để chạy lại
 * không tạo lưu lượng không cần thiết cho Overpass.
 */
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { config } from 'dotenv';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';

config({ path: '../.env', quiet: true });

const DEFAULT_OVERPASS_URL = 'https://overpass-api.de/api/interpreter';
const FALLBACK_OVERPASS_URLS = ['https://maps.mail.ru/osm/tools/overpass/api/interpreter'];
const CACHE_DIRECTORY = join(process.cwd(), 'prisma', 'seed-data', 'osm');
const ESTIMATED_SLOTS = [
  { start: '18:00', price: 350_000 },
  { start: '19:30', price: 450_000 },
  { start: '21:00', price: 400_000 },
];

interface CityQuery {
  key: string;
  displayName: string;
  bbox: readonly [number, number, number, number];
}

interface OsmElement {
  type: 'node' | 'way' | 'relation';
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

interface OverpassResponse {
  elements: OsmElement[];
}

export interface NormalizedOsmPitch {
  osmId: string;
  slug: string;
  name: string;
  district: string;
  address: string;
  lat: number;
  lng: number;
  phone: string | null;
  openingHours: string | null;
  amenities: string[];
}

const CITIES: CityQuery[] = [
  { key: 'ha-noi', displayName: 'Hà Nội', bbox: [20.8, 105.65, 21.2, 106.05] },
  {
    key: 'tp-ho-chi-minh',
    displayName: 'TP. Hồ Chí Minh',
    bbox: [10.65, 106.35, 10.95, 106.95],
  },
];

function buildQuery([south, west, north, east]: CityQuery['bbox']): string {
  const bbox = `${south},${west},${north},${east}`;
  return `[out:json][timeout:90];
(
  nwr["leisure"="pitch"]["sport"~"(^|;)soccer(;|$)"](${bbox});
  nwr["leisure"="sports_centre"]["sport"~"(^|;)soccer(;|$)"](${bbox});
);
out center tags;`;
}

async function cacheExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function fetchCity(city: CityQuery): Promise<OverpassResponse> {
  const cachePath = join(CACHE_DIRECTORY, `${city.key}.json`);
  if (await cacheExists(cachePath)) {
    return JSON.parse(await readFile(cachePath, 'utf8')) as OverpassResponse;
  }

  const endpoints = [process.env.OVERPASS_URL ?? DEFAULT_OVERPASS_URL, ...FALLBACK_OVERPASS_URLS];
  let lastError: Error | undefined;
  for (const endpoint of new Set(endpoints)) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
          'user-agent': 'Mozilla/5.0 (compatible; San7OpenDataImporter/1.0)',
        },
        body: new URLSearchParams({ data: buildQuery(city.bbox) }),
        signal: AbortSignal.timeout(120_000),
      });
      if (!response.ok) {
        lastError = new Error(`${endpoint} trả HTTP ${response.status}`);
        continue;
      }

      const payload = (await response.json()) as OverpassResponse;
      await mkdir(dirname(cachePath), { recursive: true });
      await writeFile(cachePath, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
      return payload;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
    }
  }
  throw new Error(`Không tải được OSM cho ${city.displayName}: ${lastError?.message ?? 'unknown error'}`);
}

function coordinateOf(element: OsmElement): { lat: number; lng: number } | null {
  const lat = element.lat ?? element.center?.lat;
  const lng = element.lon ?? element.center?.lon;
  return typeof lat === 'number' && typeof lng === 'number' ? { lat, lng } : null;
}

function nonEmpty(...values: Array<string | undefined>): string[] {
  return values.map((value) => value?.trim()).filter((value): value is string => Boolean(value));
}

function addressOf(tags: Record<string, string>, city: string): string {
  const explicit = tags['addr:full'] ?? tags.address;
  if (explicit?.trim()) return explicit.trim();

  const address = nonEmpty(
    tags['addr:housenumber'],
    tags['addr:street'],
    tags['addr:ward'],
    tags['addr:district'],
    tags['addr:city'],
  ).join(', ');
  return address || `Chưa có địa chỉ chi tiết, ${city}`;
}

export function normalizeOsmPitch(
  element: OsmElement,
  city: Pick<CityQuery, 'displayName'>,
): NormalizedOsmPitch | null {
  const tags = element.tags ?? {};
  const name = tags.name?.trim();
  const coordinate = coordinateOf(element);
  if (!name || !coordinate) return null;

  const osmId = `${element.type}/${element.id}`;
  const openingHours = tags.opening_hours?.trim() || null;
  return {
    osmId,
    slug: `osm-${element.type}-${element.id}`,
    name,
    district: tags['addr:district']?.trim() || tags['addr:ward']?.trim() || city.displayName,
    address: addressOf(tags, city.displayName),
    ...coordinate,
    phone: (tags.phone ?? tags['contact:phone'])?.trim() || null,
    openingHours,
    amenities: [
      'price_estimated',
      ...(openingHours ? [`opening_hours:${openingHours}`] : []),
    ],
  };
}

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const prisma = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
  });
  const summary = new Map<string, number>();

  try {
    for (const city of CITIES) {
      const response = await fetchCity(city);
      const pitches = response.elements
        .map((element) => normalizeOsmPitch(element, city))
        .filter((pitch): pitch is NormalizedOsmPitch => pitch !== null);

      for (const pitch of pitches) {
        await prisma.$executeRaw`
          INSERT INTO pitches (
            slug, osm_id, source, name, district, address, location, courts_count,
            slot_minutes, slots, price_estimated, amenities, phone, opening_hours
          ) VALUES (
            ${pitch.slug}, ${pitch.osmId}, 'osm'::"PitchSource", ${pitch.name},
            ${pitch.district}, ${pitch.address},
            ST_SetSRID(ST_MakePoint(${pitch.lng}, ${pitch.lat}), 4326)::geography,
            1, 90, ${JSON.stringify(ESTIMATED_SLOTS)}::jsonb, true,
            ${pitch.amenities}::text[], ${pitch.phone}, ${pitch.openingHours}
          )
          ON CONFLICT (osm_id) DO UPDATE SET
            slug = EXCLUDED.slug,
            source = EXCLUDED.source,
            name = EXCLUDED.name,
            district = EXCLUDED.district,
            address = EXCLUDED.address,
            location = EXCLUDED.location,
            slots = EXCLUDED.slots,
            price_estimated = EXCLUDED.price_estimated,
            amenities = EXCLUDED.amenities,
            phone = EXCLUDED.phone,
            opening_hours = EXCLUDED.opening_hours`;
      }
      summary.set(city.displayName, pitches.length);
    }
  } finally {
    await prisma.$disconnect();
  }

  for (const [city, count] of summary) console.log(`${city}: ${count} sân OSM đã upsert`);
  console.log('Nguồn dữ liệu: © OpenStreetMap contributors (ODbL).');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void main();
}
