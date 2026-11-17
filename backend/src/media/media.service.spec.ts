import type { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';
import type { AppError } from '../common/errors.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import { MediaPurpose } from './media.dto.js';
import { MediaService } from './media.service.js';

const userId = '44444444-4444-4444-8444-444444444444';
const KEY = 'public/55555555-5555-4555-8555-555555555555.webp';

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
      findFirst: vi.fn(),
      findMany: vi.fn().mockResolvedValue([]),
    },
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
  };
  const queue = { upsertJobScheduler: vi.fn().mockResolvedValue({}) };
  const service = new MediaService(config, prisma as unknown as PrismaService, queue as unknown as Queue);
  return { service, prisma, tx, queue };
}

function codeOf(e: unknown): [number, string] {
  const err = e as AppError;
  return [err.getStatus(), (err.getResponse() as { code: string }).code];
}

const dto = { purpose: MediaPurpose.post, contentType: 'image/jpeg', size: 2048 };

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
        data: expect.objectContaining({ ownerId: userId, expectedSize: 2048, publicKey: res.key }),
      }),
    );
  });

  it('mỗi lần xin được key khác nhau', async () => {
    const { service } = make();
    const [a, b] = await Promise.all([service.createImageUpload(userId, dto), service.createImageUpload(userId, dto)]);
    expect(a.key).not.toBe(b.key);
  });

  it('từ chối loại file không cho phép (415)', async () => {
    const { service } = make();
    for (const contentType of ['image/svg+xml', 'application/pdf', 'video/mp4']) {
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

  it('assertOwnedKey chỉ nhận key public/{uuid}.webp', () => {
    const { service } = make();
    expect(() => service.assertOwnedKey(userId, KEY)).not.toThrow();
    for (const key of ['users/x/post/a.jpg', 'quarantine/a.upload', 'public/../x.webp', `${KEY}x`]) {
      expect(() => service.assertOwnedKey(userId, key)).toThrow();
    }
  });

  it('gắn ảnh: key trùng → 400; ảnh chưa upload/đã hết hạn → 400 media_not_uploaded', async () => {
    const { service, prisma } = make();
    await expect(service.assertUsablePostMedia(userId, [KEY, KEY])).rejects.toMatchObject({ response: { code: 'duplicate_media_key' } });

    prisma.mediaUpload.updateMany.mockResolvedValueOnce({ count: 0 });
    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ status: 'rejected' });
    await expect(service.assertUsablePostMedia(userId, [KEY])).rejects.toMatchObject({ response: { code: 'media_not_uploaded' } });
  });

  it('ảnh đã ready thì gắn lại không xử lý lại và được đánh dấu referenced', async () => {
    const { service, prisma } = make();
    prisma.mediaUpload.updateMany.mockResolvedValueOnce({ count: 0 });
    prisma.mediaUpload.findFirst.mockResolvedValueOnce({ status: 'ready' });
    await expect(service.assertUsablePostMedia(userId, [KEY])).resolves.toBeUndefined();
    expect(prisma.mediaUpload.updateMany).toHaveBeenLastCalledWith(
      expect.objectContaining({ data: { referencedAt: expect.any(Date) } }),
    );
  });

  it('onModuleInit đăng ký job dọn upload bằng job scheduler', async () => {
    const { service, queue } = make({ S3_ENDPOINT: '', S3_PUBLIC_URL: '' });
    await service.onModuleInit();
    expect(queue.upsertJobScheduler).toHaveBeenCalledWith('media-cleanup', { every: 3_600_000 }, expect.anything());
  });
});
