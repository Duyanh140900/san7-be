import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { Readable } from 'node:stream';
import { DeleteObjectCommand, GetObjectCommand, HeadBucketCommand, S3Client } from '@aws-sdk/client-s3';
import type { ConfigService } from '@nestjs/config';
import type { StreamableFile } from '@nestjs/common';
import { config as loadEnv } from 'dotenv';
import pg from 'pg';
import sharp from 'sharp';
import type { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service.js';
import { MediaPurpose } from './media.dto.js';
import { MediaService } from './media.service.js';

/**
 * Tích hợp với SeaweedFS (S3), Postgres và Sharp thật: PUT vào quarantine ->
 * finalize -> đọc qua service. Dùng database riêng, key object riêng và tự dọn.
 * Bỏ qua nếu thiếu kho S3 hoặc Postgres.
 */
loadEnv({ path: '../.env', quiet: true });
const BASE_DB = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL ?? '';
const S3 = {
  S3_ENDPOINT: process.env.TEST_S3_ENDPOINT ?? process.env.S3_ENDPOINT ?? '',
  S3_PUBLIC_URL: process.env.TEST_S3_ENDPOINT ?? process.env.S3_PUBLIC_URL ?? '',
  S3_REGION: process.env.S3_REGION ?? 'us-east-1',
  S3_BUCKET: process.env.S3_BUCKET ?? 'media',
  S3_ACCESS_KEY: process.env.S3_ACCESS_KEY ?? '',
  S3_SECRET_KEY: process.env.S3_SECRET_KEY ?? '',
  MEDIA_PUBLIC_URL: 'http://api.test/v1/media/public',
};

function s3Client(): S3Client {
  return new S3Client({
    region: S3.S3_REGION,
    endpoint: S3.S3_ENDPOINT,
    forcePathStyle: true,
    requestChecksumCalculation: 'WHEN_REQUIRED',
    credentials: { accessKeyId: S3.S3_ACCESS_KEY, secretAccessKey: S3.S3_SECRET_KEY },
  });
}

async function probe(): Promise<boolean> {
  if (!BASE_DB || !S3.S3_ENDPOINT || !S3.S3_ACCESS_KEY) return false;
  const client = new pg.Client({ connectionString: BASE_DB });
  client.on('error', () => undefined);
  const s3 = s3Client();
  try {
    await client.connect();
    await s3.send(new HeadBucketCommand({ Bucket: S3.S3_BUCKET }));
    return true;
  } catch {
    return false;
  } finally {
    await client.end().catch(() => undefined);
    s3.destroy();
  }
}

const available = await probe();

async function bytesOf(file: StreamableFile): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const chunk of file.getStream() as Readable) chunks.push(Buffer.from(chunk as Buffer));
  return Buffer.concat(chunks);
}

describe.skipIf(!available)('MediaService với SeaweedFS + Postgres + Sharp thật', () => {
  const suffix = randomBytes(4).toString('hex');
  const dbName = `san7_it_media_${suffix}`;
  let prisma: PrismaService;
  let service: MediaService;
  let s3: S3Client;
  let ownerId: string;
  let outsiderId: string;
  let teamId: string;
  const createdKeys: string[] = [];

  const adminUrl = () => {
    const url = new URL(BASE_DB);
    url.search = '';
    return url;
  };

  beforeAll(async () => {
    const admin = new pg.Client({ connectionString: adminUrl().toString() });
    await admin.connect();
    await admin.query(`CREATE DATABASE "${dbName}"`);
    await admin.end();
    const testUrl = adminUrl();
    testUrl.pathname = `/${dbName}`;
    execFileSync('npx', ['prisma', 'migrate', 'deploy'], { env: { ...process.env, DATABASE_URL: testUrl.toString() }, stdio: 'pipe', shell: true });

    prisma = new PrismaService({ get: () => testUrl.toString() } as unknown as ConfigService<never, true>);
    const config = { get: (k: keyof typeof S3) => S3[k] } as unknown as ConfigService<never, true>;
    service = new MediaService(config, prisma, { upsertJobScheduler: () => Promise.resolve() } as unknown as Queue);
    s3 = s3Client();

    const owner = await prisma.user.create({ data: { googleSub: `o-${suffix}`, email: `o${suffix}@t.local`, name: 'Chủ ảnh' } });
    const outsider = await prisma.user.create({ data: { googleSub: `x-${suffix}`, email: `x${suffix}@t.local`, name: 'Người ngoài' } });
    const team = await prisma.team.create({ data: { name: 'FC Ảnh', crestColor: '#112233', area: 'Cầu Giấy', level: 'tb', inviteCode: `MI${suffix}`, createdById: owner.id } });
    await prisma.teamMember.create({ data: { teamId: team.id, userId: owner.id, role: 'captain', status: 'active', joinedAt: new Date() } });
    ownerId = owner.id;
    outsiderId = outsider.id;
    teamId = team.id;
  });

  afterAll(async () => {
    const rows = await prisma.mediaUpload.findMany({ select: { quarantineKey: true, publicKey: true } });
    await Promise.allSettled(
      [...rows.flatMap((r) => [r.quarantineKey, r.publicKey]), ...createdKeys].map((Key) => s3.send(new DeleteObjectCommand({ Bucket: S3.S3_BUCKET, Key }))),
    );
    s3.destroy();
    await prisma.$disconnect();
    const admin = new pg.Client({ connectionString: adminUrl().toString() });
    await admin.connect();
    await admin.query(`DROP DATABASE IF EXISTS "${dbName}" WITH (FORCE)`);
    await admin.end();
  });

  async function putImage(purpose: MediaPurpose, image: Buffer, contentType = 'image/png', extra: { teamId?: string } = {}) {
    const upload = await service.createImageUpload(ownerId, { purpose, contentType, size: image.byteLength, ...extra });
    const res = await fetch(upload.uploadUrl, { method: 'PUT', headers: upload.headers, body: new Uint8Array(image) });
    expect(res.status).toBe(200);
    return upload;
  }

  const sample = () => sharp({ create: { width: 64, height: 48, channels: 3, background: '#3366cc' } }).png().toBuffer();

  it('PUT vào quarantine -> finalize -> đọc qua readPublicImage trả WebP đã re-encode', async () => {
    const original = await sample();
    const upload = await putImage(MediaPurpose.post, original);

    // Trước finalize, ảnh public chưa tồn tại và chưa đọc được.
    const id = upload.key.replace(/^public\/|\.webp$/g, '');
    await expect(service.readPublicImage(id)).rejects.toMatchObject({ response: { code: 'media_not_found' } });

    await service.assertUsablePostMedia(ownerId, [upload.key]);

    const served = await bytesOf(await service.readPublicImage(id));
    const meta = await sharp(served).metadata();
    expect(meta.format).toBe('webp');
    expect([meta.width, meta.height]).toEqual([64, 48]);

    // Object quarantine đã bị xóa.
    const row = await prisma.mediaUpload.findFirstOrThrow({ where: { publicKey: upload.key } });
    expect(row.status).toBe('ready');
    expect(row.referencedAt).not.toBeNull();
    await expect(s3.send(new GetObjectCommand({ Bucket: S3.S3_BUCKET, Key: row.quarantineKey }))).rejects.toMatchObject({ name: 'NoSuchKey' });
  });

  it('bucket private: truy cập ẩn danh thẳng vào object bị từ chối', async () => {
    const upload = await putImage(MediaPurpose.post, await sample());
    await service.assertUsablePostMedia(ownerId, [upload.key]);
    const res = await fetch(`${S3.S3_ENDPOINT}/${S3.S3_BUCKET}/${upload.key}`);
    expect([401, 403]).toContain(res.status);
  });

  it('file không phải ảnh (SVG có script) bị từ chối và không bao giờ public', async () => {
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="5" height="5"><script>alert(1)</script></svg>');
    const upload = await putImage(MediaPurpose.post, svg, 'image/png');
    await expect(service.assertUsablePostMedia(ownerId, [upload.key])).rejects.toMatchObject({ response: { code: 'invalid_image_content' } });
    const row = await prisma.mediaUpload.findFirstOrThrow({ where: { publicKey: upload.key } });
    expect(row.status).toBe('rejected');
    await expect(s3.send(new GetObjectCommand({ Bucket: S3.S3_BUCKET, Key: row.quarantineKey }))).rejects.toMatchObject({ name: 'NoSuchKey' });
    await expect(s3.send(new GetObjectCommand({ Bucket: S3.S3_BUCKET, Key: row.publicKey }))).rejects.toMatchObject({ name: 'NoSuchKey' });
  });

  it('người khác không thể gắn ảnh của mình (IDOR)', async () => {
    const upload = await putImage(MediaPurpose.post, await sample());
    await expect(service.assertUsablePostMedia(outsiderId, [upload.key])).rejects.toMatchObject({ response: { code: 'media_forbidden' } });
  });

  it('avatar đi qua finalize và đọc công khai được', async () => {
    const upload = await putImage(MediaPurpose.avatar, await sample());
    const url = await service.useAvatar(ownerId, upload.key);
    const id = upload.key.replace(/^public\/|\.webp$/g, '');
    expect(url).toBe(`http://api.test/v1/media/public/${id}`);
    expect((await sharp(await bytesOf(await service.readPublicImage(id))).metadata()).format).toBe('webp');
  });

  it('receipt: thành viên đội đọc được, người ngoài bị chặn, endpoint public từ chối', async () => {
    const upload = await putImage(MediaPurpose.receipt, await sample(), 'image/png', { teamId });
    const done = await service.finalizeUpload(ownerId, upload.key);
    const id = upload.key.replace(/^public\/|\.webp$/g, '');
    expect(done.url).toBe(`http://api.test/v1/media/receipts/${id}`);

    expect((await sharp(await bytesOf(await service.readReceipt(ownerId, id))).metadata()).format).toBe('webp');
    await expect(service.readReceipt(outsiderId, id)).rejects.toMatchObject({ response: { code: 'media_forbidden' } });
    await expect(service.readPublicImage(id)).rejects.toMatchObject({ response: { code: 'media_not_found' } });
  });

  it('cleanupExpired xóa object quarantine và ảnh chưa tham chiếu đã hết hạn, giữ ảnh đã tham chiếu', async () => {
    const orphan = await putImage(MediaPurpose.post, await sample());
    const kept = await putImage(MediaPurpose.avatar, await sample());
    await service.useAvatar(ownerId, kept.key);
    await prisma.mediaUpload.updateMany({ where: { publicKey: { in: [orphan.key, kept.key] } }, data: { expiresAt: new Date(Date.now() - 1000) } });

    const deleted = await service.cleanupExpired();
    expect(deleted).toBeGreaterThanOrEqual(1);

    const orphanRow = await prisma.mediaUpload.findFirstOrThrow({ where: { publicKey: orphan.key } });
    expect(orphanRow.status).toBe('expired');
    await expect(s3.send(new GetObjectCommand({ Bucket: S3.S3_BUCKET, Key: orphanRow.quarantineKey }))).rejects.toMatchObject({ name: 'NoSuchKey' });
    const keptRow = await prisma.mediaUpload.findFirstOrThrow({ where: { publicKey: kept.key } });
    expect(keptRow.status).toBe('ready');
    await expect(s3.send(new GetObjectCommand({ Bucket: S3.S3_BUCKET, Key: kept.key }))).resolves.toBeDefined();
  });
});
