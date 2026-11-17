import { Readable } from 'node:stream';
import type { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';
import sharp from 'sharp';
import type { AppError } from '../common/errors.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { MediaPurpose } from './media.dto.js';
import { MediaService } from './media.service.js';

const userId = '44444444-4444-4444-8444-444444444444';
const teamId = '66666666-6666-4666-8666-666666666666';
const ID = '55555555-5555-4555-8555-555555555555';
const KEY = `public/${ID}.webp`;

function make(overrides: Record<string, string> = {}, quotaUsed = 0) {
  const env: Record<string, string> = {
    S3_ENDPOINT: 'http://storage:8333',
    S3_PUBLIC_URL: 'http://localhost:8333/',
    MEDIA_PUBLIC_URL: 'http://api.test/v1/media/public',
    S3_REGION: 'us-east-1',
    S3_BUCKET: 'media',
    S3_ACCESS_KEY: 'access',
    S3_SECRET_KEY: 'secret',
    ...overrides,
  };
  const config = { get: (k: string) => env[k] } as unknown as ConfigService<never, true>;
  const tx = {
    mediaUpload: {
      aggregate: vi.fn().mockResolvedValue({ _sum: { expectedSize: quotaUsed } }),
      create: vi.fn().mockResolvedValue({}),
    },
  };
  const prisma = {
    mediaUpload: {
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      update: vi.fn().mockResolvedValue({}),
      findFirst: vi.fn().mockResolvedValue({ id: ID }),
      findFirstOrThrow: vi.fn(),
      findMany: vi.fn().mockResolvedValue([]),
    },
    teamMember: { findFirst: vi.fn().mockResolvedValue({ id: 'm1' }) },
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
  };
  const queue = { upsertJobScheduler: vi.fn().mockResolvedValue({}) };
  const service = new MediaService(config, prisma as unknown as PrismaService, queue as unknown as Queue);
  const s3 = { send: vi.fn().mockResolvedValue({}) };
  Object.defineProperty(service, 'admin', { value: s3 });
  return { service, prisma, tx, queue, s3 };
}

function codeOf(e: unknown): [number, string] {
  const err = e as AppError;
  return [err.getStatus(), (err.getResponse() as { code: string }).code];
}

const dto = { purpose: MediaPurpose.post, contentType: 'image/jpeg', size: 2048 };

async function png(width = 8, height = 8): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: '#33aa55' } }).png().toBuffer();
}

function body(bytes: Buffer) {
  return { Body: { transformToByteArray: () => Promise.resolve(new Uint8Array(bytes)) } };
}

describe('MediaService - quarantine upload', () => {
  it('ghi ý định upload, ký PUT vào quarantine và trả key public/URL qua API', async () => {
    const { service, tx } = make();
    const res = await service.createImageUpload(userId, dto);

    expect(res.key).toMatch(/^public\/[0-9a-f-]{36}\.webp$/);
    const url = new URL(res.uploadUrl);
    expect(url.origin).toBe('http://localhost:8333');
    expect(url.pathname).toMatch(/^\/media\/quarantine\/[0-9a-f-]{36}\.upload$/);
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain('content-length');
    expect(res.publicUrl).toMatch(/^http:\/\/api\.test\/v1\/media\/public\/[0-9a-f-]{36}$/);
    expect(res.headers).toEqual({ 'Content-Type': 'image/jpeg' });
    expect(tx.mediaUpload.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ ownerId: userId, expectedSize: 2048, publicKey: res.key, teamId: null }),
      }),
    );
  });

  it('mỗi lần xin được key khác nhau', async () => {
    const { service } = make();
    const [a, b] = await Promise.all([service.createImageUpload(userId, dto), service.createImageUpload(userId, dto)]);
    expect(a.key).not.toBe(b.key);
  });

  it('từ chối loại file không cho phép, kể cả HEIC (415)', async () => {
    const { service } = make();
    for (const contentType of ['image/svg+xml', 'application/pdf', 'video/mp4', 'image/heic']) {
      const err = await service.createImageUpload(userId, { ...dto, contentType }).catch((e: unknown) => e);
      expect(codeOf(err)).toEqual([415, 'media_type_not_allowed']);
    }
  });

  it('từ chối ảnh quá 10MB (413)', async () => {
    const err = await make().service.createImageUpload(userId, { ...dto, size: 10 * 1024 * 1024 + 1 }).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([413, 'media_too_large']);
  });

  it('vượt quota ngày → 429 và không tạo bản ghi', async () => {
    const { service, tx } = make({}, 50 * 1024 * 1024 - 100);
    const err = await service.createImageUpload(userId, dto).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([429, 'media_daily_quota_exceeded']);
    expect(tx.mediaUpload.create).not.toHaveBeenCalled();
  });

  it('chưa cấu hình S3 → 503 storage_unavailable', async () => {
    const err = await make({ S3_ENDPOINT: '', S3_PUBLIC_URL: '' }).service.createImageUpload(userId, dto).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([503, 'storage_unavailable']);
  });

  it('receipt: bắt buộc teamId và phải là thành viên active; URL trỏ endpoint biên lai', async () => {
    const { service, prisma, tx } = make();
    const receipt = { purpose: MediaPurpose.receipt, contentType: 'image/png', size: 100 };

    expect(codeOf(await service.createImageUpload(userId, receipt).catch((e: unknown) => e))).toEqual([400, 'team_required']);

    prisma.teamMember.findFirst.mockResolvedValueOnce(null);
    expect(codeOf(await service.createImageUpload(userId, { ...receipt, teamId }).catch((e: unknown) => e))).toEqual([403, 'not_team_member']);

    const res = await service.createImageUpload(userId, { ...receipt, teamId });
    expect(res.publicUrl).toMatch(/^http:\/\/api\.test\/v1\/media\/receipts\/[0-9a-f-]{36}$/);
    expect(tx.mediaUpload.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ teamId }) }));
  });

  it('onModuleInit đăng ký job dọn upload bằng job scheduler', async () => {
    const { service, queue } = make({ S3_ENDPOINT: '', S3_PUBLIC_URL: '' });
    await service.onModuleInit();
    expect(queue.upsertJobScheduler).toHaveBeenCalledWith('media-cleanup', { every: 3_600_000 }, expect.anything());
  });
});

describe('MediaService - quyền sở hữu key', () => {
  it('assertOwnedKey kiểm tra ownerId trong DB, không chỉ regex', async () => {
    const { service, prisma } = make();
    await expect(service.assertOwnedKey(userId, KEY)).resolves.toBeUndefined();
    expect(prisma.mediaUpload.findFirst).toHaveBeenCalledWith({ where: { publicKey: KEY, ownerId: userId }, select: { id: true } });

    prisma.mediaUpload.findFirst.mockResolvedValueOnce(null);
    await expect(service.assertOwnedKey('someone-else', KEY)).rejects.toMatchObject({ response: { code: 'media_forbidden' } });
  });

  it('key sai định dạng bị từ chối mà không truy vấn DB', async () => {
    const { service, prisma } = make();
    for (const key of ['users/x/post/a.jpg', 'quarantine/a.upload', 'public/../x.webp', `${KEY}x`]) {
      await expect(service.assertOwnedKey(userId, key)).rejects.toMatchObject({ response: { code: 'media_forbidden' } });
    }
    expect(prisma.mediaUpload.findFirst).not.toHaveBeenCalled();
  });

  it('gắn ảnh người khác (IDOR) → 403', async () => {
    const { service, prisma } = make();
    prisma.mediaUpload.findFirst.mockResolvedValueOnce(null);
    await expect(service.assertUsablePostMedia(userId, [KEY])).rejects.toMatchObject({ response: { code: 'media_forbidden' } });
  });

  it('gắn ảnh: key trùng → 400; ảnh chưa upload/đã hết hạn → 400 media_not_uploaded', async () => {
    const { service, prisma } = make();
    await expect(service.assertUsablePostMedia(userId, [KEY, KEY])).rejects.toMatchObject({ response: { code: 'duplicate_media_key' } });

    prisma.mediaUpload.updateMany.mockResolvedValueOnce({ count: 0 });
    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ id: ID }).mockResolvedValueOnce({ status: 'rejected' });
    await expect(service.assertUsablePostMedia(userId, [KEY])).rejects.toMatchObject({ response: { code: 'media_not_uploaded' } });
  });

  it('ảnh đã ready thì gắn lại không xử lý lại và được đánh dấu referenced', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.updateMany.mockResolvedValueOnce({ count: 0 });
    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ id: ID }).mockResolvedValueOnce({ status: 'ready' });
    await expect(service.assertUsablePostMedia(userId, [KEY])).resolves.toBeUndefined();
    expect(s3.send).not.toHaveBeenCalled();
    expect(prisma.mediaUpload.updateMany).toHaveBeenLastCalledWith(expect.objectContaining({ data: { referencedAt: expect.any(Date) } }));
  });
});

describe('MediaService.finalize (qua assertUsablePostMedia / useAvatar)', () => {
  function pending(prisma: ReturnType<typeof make>['prisma'], expectedSize: number) {
    prisma.mediaUpload.findFirstOrThrow.mockResolvedValue({ id: ID, quarantineKey: `quarantine/${ID}.upload`, expectedSize });
  }

  it('ảnh hợp lệ: re-encode WebP, ghi public, xóa quarantine, đặt ready', async () => {
    const { service, prisma, s3 } = make();
    const source = await png();
    pending(prisma, source.byteLength);
    s3.send.mockResolvedValueOnce(body(source)).mockResolvedValue({});

    await service.assertUsablePostMedia(userId, [KEY]);

    const calls = s3.send.mock.calls.map((c) => c[0] as { constructor: { name: string }; input: Record<string, unknown> });
    expect(calls.map((c) => c.constructor.name)).toEqual(['GetObjectCommand', 'PutObjectCommand', 'DeleteObjectCommand']);
    expect(calls[1]!.input).toMatchObject({ Key: KEY, ContentType: 'image/webp' });
    const written = calls[1]!.input.Body as Buffer;
    expect((await sharp(written).metadata()).format).toBe('webp');
    expect(calls[2]!.input).toMatchObject({ Key: `quarantine/${ID}.upload` });
    expect(prisma.mediaUpload.update).toHaveBeenCalledWith({ where: { id: ID }, data: { status: 'ready', finalizedAt: expect.any(Date) } });
  });

  it('nội dung không phải ảnh → 415, xóa quarantine, đặt rejected', async () => {
    const { service, prisma, s3 } = make();
    const junk = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
    pending(prisma, junk.byteLength);
    s3.send.mockResolvedValueOnce(body(junk)).mockResolvedValue({});

    const err = await service.assertUsablePostMedia(userId, [KEY]).catch((e: unknown) => e);

    expect(codeOf(err)).toEqual([415, 'invalid_image_content']);
    expect(prisma.mediaUpload.update).toHaveBeenCalledWith({ where: { id: ID }, data: { status: 'rejected' } });
    const names = s3.send.mock.calls.map((c) => (c[0] as { constructor: { name: string } }).constructor.name);
    expect(names).toEqual(['GetObjectCommand', 'DeleteObjectCommand']);
  });

  it('SVG hợp lệ (Sharp đọc được) vẫn bị từ chối vì ngoài whitelist định dạng', async () => {
    const { service, prisma, s3 } = make();
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>');
    pending(prisma, svg.byteLength);
    s3.send.mockResolvedValueOnce(body(svg)).mockResolvedValue({});
    const err = await service.assertUsablePostMedia(userId, [KEY]).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([415, 'invalid_image_content']);
  });

  it('dung lượng thực tế khác dung lượng đã khai → rejected', async () => {
    const { service, prisma, s3 } = make();
    const source = await png();
    pending(prisma, source.byteLength + 1);
    s3.send.mockResolvedValueOnce(body(source)).mockResolvedValue({});

    const err = await service.assertUsablePostMedia(userId, [KEY]).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([415, 'invalid_image_content']);
    expect(prisma.mediaUpload.update).toHaveBeenCalledWith({ where: { id: ID }, data: { status: 'rejected' } });
  });

  it('ảnh vượt giới hạn số điểm ảnh (decompression bomb) → rejected', async () => {
    const { service, prisma, s3 } = make();
    const big = await sharp({ create: { width: 7000, height: 6000, channels: 3, background: '#000' } }).png({ compressionLevel: 9 }).toBuffer();
    pending(prisma, big.byteLength);
    s3.send.mockResolvedValueOnce(body(big)).mockResolvedValue({});

    const err = await service.assertUsablePostMedia(userId, [KEY]).catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([415, 'invalid_image_content']);
  });

  it('useAvatar: finalize với purpose avatar, đánh dấu referenced và trả URL công khai', async () => {
    const { service, prisma, s3 } = make();
    const source = await png();
    pending(prisma, source.byteLength);
    s3.send.mockResolvedValueOnce(body(source)).mockResolvedValue({});

    const url = await service.useAvatar(userId, KEY);

    expect(url).toBe(`http://api.test/v1/media/public/${ID}`);
    expect(prisma.mediaUpload.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ purpose: 'avatar', status: 'pending' }) }),
    );
    expect(prisma.mediaUpload.updateMany).toHaveBeenLastCalledWith(expect.objectContaining({ data: { referencedAt: expect.any(Date) } }));
  });

  it('finalizeUpload: receipt đi qua finalize và trả URL biên lai; ảnh post bị từ chối ở endpoint này', async () => {
    const { service, prisma, s3 } = make();
    const source = await png();
    pending(prisma, source.byteLength);
    s3.send.mockResolvedValueOnce(body(source)).mockResolvedValue({});

    prisma.mediaUpload.findFirstOrThrow.mockResolvedValueOnce({ purpose: 'receipt' });
    const res = await service.finalizeUpload(userId, KEY);
    expect(res).toEqual({ key: KEY, url: `http://api.test/v1/media/receipts/${ID}` });

    prisma.mediaUpload.findFirstOrThrow.mockResolvedValueOnce({ purpose: 'post' });
    await expect(service.finalizeUpload(userId, KEY)).rejects.toMatchObject({ response: { code: 'media_purpose_not_supported' } });
  });
});

describe('MediaService - đọc ảnh', () => {
  it('readPublicImage chỉ nhận post/avatar đã ready (receipt bị loại trong truy vấn)', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ publicKey: KEY });
    s3.send.mockResolvedValueOnce({ Body: Readable.from([Buffer.from('x')]) });

    await service.readPublicImage(ID);

    expect(prisma.mediaUpload.findFirst).toHaveBeenCalledWith({
      where: { id: ID, publicKey: KEY, status: 'ready', purpose: { in: ['post', 'avatar'] } },
      select: { publicKey: true },
    });
  });

  it('readPublicImage: không có bản ghi ready → 404; object mất → 404', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.findFirst.mockResolvedValueOnce(null);
    expect(codeOf(await service.readPublicImage(ID).catch((e: unknown) => e))).toEqual([404, 'media_not_found']);

    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ publicKey: KEY });
    s3.send.mockRejectedValueOnce(new Error('NoSuchKey'));
    expect(codeOf(await service.readPublicImage(ID).catch((e: unknown) => e))).toEqual([404, 'media_not_found']);
  });

  it('readReceipt: chỉ thành viên active của đội; người ngoài → 403; chưa gắn đội → 404', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.findFirst.mockResolvedValue({ publicKey: KEY, teamId });
    s3.send.mockResolvedValue({ Body: Readable.from([Buffer.from('x')]) });

    await expect(service.readReceipt(userId, ID)).resolves.toBeDefined();
    expect(prisma.teamMember.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { teamId, userId, status: 'active' } }));

    prisma.teamMember.findFirst.mockResolvedValueOnce(null);
    expect(codeOf(await service.readReceipt('outsider', ID).catch((e: unknown) => e))).toEqual([403, 'media_forbidden']);

    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ publicKey: KEY, teamId: null });
    expect(codeOf(await service.readReceipt(userId, ID).catch((e: unknown) => e))).toEqual([404, 'media_not_found']);
  });
});

describe('MediaService.cleanupExpired', () => {
  const rows = (n: number, from = 0) =>
    Array.from({ length: n }, (_, i) => {
      const id = `id-${String(from + i).padStart(4, '0')}`;
      return { id, quarantineKey: `quarantine/${id}.upload`, publicKey: `public/${id}.webp` };
    });

  it('lặp theo batch đến khi hết việc', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.findMany
      .mockResolvedValueOnce(rows(100))
      .mockResolvedValueOnce(rows(100, 100))
      .mockResolvedValueOnce(rows(30, 200));

    const total = await service.cleanupExpired(new Date());

    expect(total).toBe(230);
    expect(prisma.mediaUpload.findMany).toHaveBeenCalledTimes(3);
    expect(s3.send).toHaveBeenCalledTimes(460);
    expect(prisma.mediaUpload.findMany.mock.calls[1]![0].where.id).toEqual({ gt: 'id-0099' });
  });

  it('dừng ngay khi không còn bản ghi và chỉ chọn bản ghi chưa tham chiếu, đã hết hạn', async () => {
    const { service, prisma } = make();
    const now = new Date('2026-11-17T00:00:00Z');
    expect(await service.cleanupExpired(now)).toBe(0);
    expect(prisma.mediaUpload.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.mediaUpload.findMany.mock.calls[0]![0].where).toMatchObject({
      referencedAt: null,
      expiresAt: { lte: now },
      status: { in: ['pending', 'processing', 'ready', 'rejected'] },
    });
  });

  it('xóa object lỗi thì giữ bản ghi để thử lại và không lặp vô hạn', async () => {
    const { service, prisma, s3 } = make();
    prisma.mediaUpload.findMany.mockResolvedValueOnce(rows(2)).mockResolvedValueOnce([]);
    s3.send.mockRejectedValueOnce(new Error('s3 down')).mockResolvedValue({});

    const total = await service.cleanupExpired();

    expect(total).toBe(1);
    expect(prisma.mediaUpload.updateMany).toHaveBeenCalledTimes(1);
    expect(prisma.mediaUpload.updateMany).toHaveBeenCalledWith({ where: { id: 'id-0001', referencedAt: null }, data: { status: 'expired' } });
  });

  it('không cấu hình S3 thì không làm gì', async () => {
    const { service, prisma } = make({ S3_ENDPOINT: '', S3_PUBLIC_URL: '' });
    Object.defineProperty(service, 'admin', { value: undefined });
    expect(await service.cleanupExpired()).toBe(0);
    expect(prisma.mediaUpload.findMany).not.toHaveBeenCalled();
  });
});
