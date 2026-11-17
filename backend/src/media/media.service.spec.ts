import type { ConfigService } from '@nestjs/config';
import { AppError } from '../common/errors.js';
import { MediaPurpose } from './media.dto.js';
import { MediaService } from './media.service.js';

const userId = '44444444-4444-4444-8444-444444444444';

function make(overrides: Record<string, string> = {}) {
  const env: Record<string, string> = {
    S3_ENDPOINT: 'http://storage:8333',
    S3_PUBLIC_URL: 'http://localhost:8333/',
    S3_REGION: 'us-east-1',
    S3_BUCKET: 'media',
    S3_ACCESS_KEY: 'access',
    S3_SECRET_KEY: 'secret',
    ...overrides,
  };
  const config = { get: (k: string) => env[k] } as unknown as ConfigService<
    never,
    true
  >;
  return new MediaService(config);
}

function codeOf(e: unknown): [number, string] {
  const err = e as AppError;
  return [err.getStatus(), (err.getResponse() as { code: string }).code];
}

describe('MediaService - presigned upload', () => {
  it('ký URL PUT theo host công khai, key theo user, khoá Content-Type/Length', async () => {
    const service = make();
    const res = await service.createImageUpload(userId, {
      purpose: MediaPurpose.post,
      contentType: 'image/jpeg',
      size: 2048,
    });

    expect(res.key).toMatch(
      new RegExp(`^users/${userId}/post/[0-9a-f-]{36}\\.jpg$`),
    );
    const url = new URL(res.uploadUrl);
    expect(url.origin).toBe('http://localhost:8333');
    expect(url.pathname).toBe(`/media/${res.key}`);
    expect(url.searchParams.get('X-Amz-Expires')).toBe('300');
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain(
      'content-type',
    );
    expect(url.searchParams.get('X-Amz-SignedHeaders')).toContain(
      'content-length',
    );
    expect(url.searchParams.has('x-amz-checksum-crc32')).toBe(false);
    expect(res.headers).toEqual({ 'Content-Type': 'image/jpeg' });
    expect(res.publicUrl).toBe(`http://localhost:8333/media/${res.key}`);
    expect(res.method).toBe('PUT');
  });

  it('mỗi lần xin được key khác nhau', async () => {
    const service = make();
    const dto = {
      purpose: MediaPurpose.avatar,
      contentType: 'image/png',
      size: 10,
    };
    const [a, b] = await Promise.all([
      service.createImageUpload(userId, dto),
      service.createImageUpload(userId, dto),
    ]);
    expect(a.key).not.toBe(b.key);
  });

  it('từ chối loại file không phải ảnh cho phép (415)', async () => {
    const service = make();
    for (const contentType of [
      'image/svg+xml',
      'application/pdf',
      'video/mp4',
    ]) {
      const err = await service
        .createImageUpload(userId, {
          purpose: MediaPurpose.post,
          contentType,
          size: 100,
        })
        .catch((e: unknown) => e);
      expect(codeOf(err)).toEqual([415, 'media_type_not_allowed']);
    }
  });

  it('từ chối ảnh quá 10MB (413)', async () => {
    const err = await make()
      .createImageUpload(userId, {
        purpose: MediaPurpose.post,
        contentType: 'image/webp',
        size: 10 * 1024 * 1024 + 1,
      })
      .catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([413, 'media_too_large']);
  });

  it('chưa cấu hình S3 → 503 storage_unavailable', async () => {
    const err = await make({ S3_ENDPOINT: '', S3_PUBLIC_URL: '' })
      .createImageUpload(userId, {
        purpose: MediaPurpose.post,
        contentType: 'image/png',
        size: 100,
      })
      .catch((e: unknown) => e);
    expect(codeOf(err)).toEqual([503, 'storage_unavailable']);
  });

  it('assertOwnedKey chỉ nhận key dưới users/{userId}/', () => {
    const service = make();
    expect(() =>
      service.assertOwnedKey(userId, `users/${userId}/post/a.jpg`),
    ).not.toThrow();
    for (const key of [
      'users/other/post/a.jpg',
      `users/${userId}x/post/a.jpg`,
      `users/${userId}/../other/a.jpg`,
    ]) {
      expect(() => service.assertOwnedKey(userId, key)).toThrow(AppError);
    }
  });

  it('chỉ cho gắn ảnh post đã tải lên, đúng loại và không quá giới hạn', async () => {
    const service = make();
    const admin = { send: vi.fn().mockResolvedValue({
      ContentType: 'image/png',
      ContentLength: 10,
    }) };
    Object.defineProperty(service, 'admin', { value: admin });
    const key = `users/${userId}/post/a.png`;

    await expect(service.assertUsablePostMedia(userId, [key])).resolves.toBeUndefined();
    expect(admin.send).toHaveBeenCalledTimes(1);

    await expect(
      service.assertUsablePostMedia(userId, [`users/${userId}/avatar/a.png`]),
    ).rejects.toMatchObject({ response: { code: 'media_forbidden' } });

    admin.send.mockResolvedValueOnce({
      ContentType: 'image/png',
      ContentLength: 10 * 1024 * 1024 + 1,
    });
    await expect(service.assertUsablePostMedia(userId, [key])).rejects.toMatchObject({
      response: { code: 'media_too_large' },
    });
  });
});
