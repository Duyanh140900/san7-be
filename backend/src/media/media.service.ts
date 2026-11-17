import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import {
  CreateBucketCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { InjectQueue } from '@nestjs/bullmq';
import { HttpStatus, Injectable, Logger, OnModuleInit, StreamableFile } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';
import sharp from 'sharp';
import { AppError } from '../common/errors.js';
import type { Env } from '../common/env.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import {
  DAILY_UPLOAD_QUOTA_BYTES,
  IMAGE_TYPES,
  MAX_IMAGE_BYTES,
  MAX_IMAGE_PIXELS,
  UPLOAD_URL_TTL_SECONDS,
  MediaPurpose,
  type CreateUploadDto,
  type FinalizedMediaDto,
  type UploadUrlDto,
} from './media.dto.js';

/** Object client PUT luôn nằm ở quarantine; chỉ ảnh đã Sharp decode + re-encode mới public. */
@Injectable()
export class MediaService implements OnModuleInit {
  private readonly logger = new Logger(MediaService.name);
  private readonly bucket: string;
  private readonly uploadUrlBase: string;
  private readonly mediaUrlBase: string;
  private readonly receiptUrlBase: string;
  private readonly admin?: S3Client;
  private readonly signer?: S3Client;

  constructor(
    config: ConfigService<Env, true>,
    private readonly prisma: PrismaService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
  ) {
    const endpoint = config.get('S3_ENDPOINT', { infer: true });
    const publicUrl = config.get('S3_PUBLIC_URL', { infer: true });
    this.bucket = config.get('S3_BUCKET', { infer: true });
    this.uploadUrlBase = (publicUrl || endpoint).replace(/\/+$/, '');
    this.mediaUrlBase = config.get('MEDIA_PUBLIC_URL', { infer: true }).replace(/\/+$/, '');
    this.receiptUrlBase = `${this.mediaUrlBase.replace(/\/public$/, '')}/receipts`;
    if (!endpoint) return;
    const base = {
      region: config.get('S3_REGION', { infer: true }), forcePathStyle: true,
      requestChecksumCalculation: 'WHEN_REQUIRED' as const,
      credentials: { accessKeyId: config.get('S3_ACCESS_KEY', { infer: true }), secretAccessKey: config.get('S3_SECRET_KEY', { infer: true }) },
    };
    this.admin = new S3Client({ ...base, endpoint });
    this.signer = new S3Client({ ...base, endpoint: this.uploadUrlBase });
  }

  async onModuleInit(): Promise<void> {
    if (this.admin) {
      try { await this.admin.send(new HeadBucketCommand({ Bucket: this.bucket })); }
      catch {
        try { await this.admin.send(new CreateBucketCommand({ Bucket: this.bucket })); this.logger.log(`Đã tạo bucket ${this.bucket}`); }
        catch (err) { this.logger.warn(`Chưa chuẩn bị được bucket ${this.bucket}: ${(err as Error).message}`); }
      }
    }
    await this.queue.upsertJobScheduler(
      'media-cleanup',
      { every: 60 * 60 * 1000 },
      { name: Jobs.mediaCleanup, data: {}, opts: { removeOnComplete: true, removeOnFail: 100 } },
    ).catch((err: unknown) => this.logger.warn(`Không lên lịch dọn upload: ${(err as Error).message}`));
  }

  async createImageUpload(userId: string, dto: CreateUploadDto): Promise<UploadUrlDto> {
    if (!this.signer) throw this.storageUnavailable();
    const contentType = dto.contentType.toLowerCase();
    if (!(contentType in IMAGE_TYPES)) throw new AppError(HttpStatus.UNSUPPORTED_MEDIA_TYPE, 'media_type_not_allowed', 'Chỉ nhận ảnh JPEG, PNG, WebP hoặc HEIC');
    if (dto.size > MAX_IMAGE_BYTES) throw new AppError(HttpStatus.PAYLOAD_TOO_LARGE, 'media_too_large', 'Ảnh tối đa 10MB');

    const teamId = await this.resolveUploadTeam(userId, dto);
    const now = new Date();
    const id = randomUUID();
    const quarantineKey = `quarantine/${id}.upload`;
    const publicKey = `public/${id}.webp`;
    const expiresAt = new Date(now.getTime() + UPLOAD_URL_TTL_SECONDS * 1000);
    await this.prisma.$transaction(async (tx) => {
      const quota = await tx.mediaUpload.aggregate({ where: { ownerId: userId, createdAt: { gte: startOfUtcDay(now) } }, _sum: { expectedSize: true } });
      if ((quota._sum.expectedSize ?? 0) + dto.size > DAILY_UPLOAD_QUOTA_BYTES) {
        throw new AppError(HttpStatus.TOO_MANY_REQUESTS, 'media_daily_quota_exceeded', 'Đã dùng hết quota tải ảnh hôm nay');
      }
      await tx.mediaUpload.create({ data: { id, ownerId: userId, teamId, purpose: dto.purpose, expectedSize: dto.size, quarantineKey, publicKey, expiresAt } });
    }, { isolationLevel: 'Serializable' });
    const uploadUrl = await getSignedUrl(this.signer, new PutObjectCommand({
      Bucket: this.bucket, Key: quarantineKey, ContentType: contentType, ContentLength: dto.size,
    }), { expiresIn: UPLOAD_URL_TTL_SECONDS, signableHeaders: new Set(['content-type', 'content-length']) });
    return { method: 'PUT', uploadUrl, headers: { 'Content-Type': contentType }, key: publicKey, publicUrl: this.urlFor(dto.purpose, publicKey), expiresIn: UPLOAD_URL_TTL_SECONDS };
  }

  /** URL API phục vụ ảnh post/avatar đã xử lý, không lộ object S3/quarantine. */
  publicUrlFor(key: string): string {
    return this.urlFor(MediaPurpose.post, key);
  }

  private urlFor(purpose: MediaPurpose | string, key: string): string {
    const id = /^public\/([0-9a-f-]{36})\.webp$/i.exec(key)?.[1];
    if (!id) return `${this.mediaUrlBase}/missing`;
    return `${purpose === MediaPurpose.receipt ? this.receiptUrlBase : this.mediaUrlBase}/${id}`;
  }

  /** Key phải đúng định dạng và là upload của chính user này trong DB. */
  async assertOwnedKey(userId: string, key: string): Promise<void> {
    const owned = PUBLIC_KEY_PATTERN.test(key)
      ? await this.prisma.mediaUpload.findFirst({ where: { publicKey: key, ownerId: userId }, select: { id: true } })
      : null;
    if (!owned) throw new AppError(HttpStatus.FORBIDDEN, 'media_forbidden', 'Ảnh không thuộc về bạn');
  }

  /** Finalize mỗi key đúng một lần, rồi đánh dấu chúng đã được tham chiếu. */
  async assertUsablePostMedia(userId: string, keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    if (new Set(keys).size !== keys.length) throw new AppError(HttpStatus.BAD_REQUEST, 'duplicate_media_key', 'Không được chọn trùng ảnh');
    for (const key of keys) {
      await this.assertOwnedKey(userId, key);
      await this.finalize(userId, key, 'post');
    }
    await this.prisma.mediaUpload.updateMany({ where: { ownerId: userId, publicKey: { in: keys }, status: 'ready' }, data: { referencedAt: new Date() } });
  }

  /** Ảnh đại diện: xác minh + xử lý lại rồi trả URL công khai để lưu vào hồ sơ. */
  async useAvatar(userId: string, key: string): Promise<string> {
    await this.assertOwnedKey(userId, key);
    await this.finalize(userId, key, MediaPurpose.avatar);
    await this.markReferenced(userId, key);
    return this.urlFor(MediaPurpose.avatar, key);
  }

  /** Hoàn tất upload avatar/receipt sau khi app đã PUT lên quarantine. */
  async finalizeUpload(userId: string, key: string): Promise<FinalizedMediaDto> {
    await this.assertOwnedKey(userId, key);
    const upload = await this.prisma.mediaUpload.findFirstOrThrow({ where: { publicKey: key, ownerId: userId }, select: { purpose: true } });
    if (upload.purpose === MediaPurpose.post) {
      throw new AppError(HttpStatus.BAD_REQUEST, 'media_purpose_not_supported', 'Ảnh kèo được xử lý khi đăng bài');
    }
    await this.finalize(userId, key, upload.purpose);
    await this.markReferenced(userId, key);
    return { key, url: this.urlFor(upload.purpose, key) };
  }

  private async markReferenced(userId: string, key: string): Promise<void> {
    await this.prisma.mediaUpload.updateMany({ where: { ownerId: userId, publicKey: key, status: 'ready' }, data: { referencedAt: new Date() } });
  }

  private async resolveUploadTeam(userId: string, dto: CreateUploadDto): Promise<string | null> {
    if (dto.purpose !== MediaPurpose.receipt) return null;
    if (!dto.teamId) throw new AppError(HttpStatus.BAD_REQUEST, 'team_required', 'Biên lai phải gắn với một đội');
    const member = await this.prisma.teamMember.findFirst({ where: { teamId: dto.teamId, userId, status: 'active' }, select: { id: true } });
    if (!member) throw new AppError(HttpStatus.FORBIDDEN, 'not_team_member', 'Bạn không thuộc đội này');
    return dto.teamId;
  }

  /** Ảnh post/avatar: công khai. Biên lai không bao giờ được phục vụ ở đây. */
  async readPublicImage(id: string): Promise<StreamableFile> {
    const upload = await this.prisma.mediaUpload.findFirst({
      where: { id, publicKey: `public/${id}.webp`, status: 'ready', purpose: { in: [MediaPurpose.post, MediaPurpose.avatar] } },
      select: { publicKey: true },
    });
    if (!upload) throw new AppError(HttpStatus.NOT_FOUND, 'media_not_found', 'Không tìm thấy ảnh');
    return this.streamObject(upload.publicKey);
  }

  /** Biên lai quỹ: chỉ thành viên active của đội gắn với ảnh. */
  async readReceipt(userId: string, id: string): Promise<StreamableFile> {
    const upload = await this.prisma.mediaUpload.findFirst({
      where: { id, publicKey: `public/${id}.webp`, status: 'ready', purpose: MediaPurpose.receipt, teamId: { not: null } },
      select: { publicKey: true, teamId: true },
    });
    if (!upload?.teamId) throw new AppError(HttpStatus.NOT_FOUND, 'media_not_found', 'Không tìm thấy ảnh');
    const member = await this.prisma.teamMember.findFirst({ where: { teamId: upload.teamId, userId, status: 'active' }, select: { id: true } });
    if (!member) throw new AppError(HttpStatus.FORBIDDEN, 'media_forbidden', 'Chỉ thành viên đội được xem biên lai');
    return this.streamObject(upload.publicKey);
  }

  private async streamObject(key: string): Promise<StreamableFile> {
    if (!this.admin) throw this.storageUnavailable();
    try {
      const object = await this.admin.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      if (!object.Body || !(object.Body instanceof Readable)) throw new Error('empty object body');
      return new StreamableFile(object.Body, { type: 'image/webp', disposition: 'inline' });
    } catch {
      throw new AppError(HttpStatus.NOT_FOUND, 'media_not_found', 'Không tìm thấy ảnh');
    }
  }

  /** Job BullMQ: xóa object quarantine/ảnh chưa được tham chiếu khi hết hạn; lặp theo batch đến hết việc. */
  async cleanupExpired(now = new Date()): Promise<number> {
    const admin = this.admin;
    if (!admin) return 0;
    let cursor: string | undefined;
    let total = 0;
    for (let round = 0; round < CLEANUP_MAX_BATCHES; round++) {
      const batch = await this.prisma.mediaUpload.findMany({
        where: {
          referencedAt: null,
          expiresAt: { lte: now },
          status: { in: ['pending', 'processing', 'ready', 'rejected'] },
          ...(cursor ? { id: { gt: cursor } } : {}),
        },
        orderBy: { id: 'asc' },
        take: CLEANUP_BATCH_SIZE,
        select: { id: true, quarantineKey: true, publicKey: true },
      });
      if (batch.length === 0) break;
      cursor = batch[batch.length - 1]!.id;
      for (const row of batch) {
        const results = await Promise.allSettled([
          admin.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: row.quarantineKey })),
          admin.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: row.publicKey })),
        ]);
        // Xóa lỗi thì giữ nguyên bản ghi để lần chạy sau thử lại.
        if (results.some((r) => r.status === 'rejected')) continue;
        const done = await this.prisma.mediaUpload.updateMany({ where: { id: row.id, referencedAt: null }, data: { status: 'expired' } });
        total += done.count;
      }
      if (batch.length < CLEANUP_BATCH_SIZE) break;
    }
    return total;
  }

  private async finalize(userId: string, publicKey: string, purpose: string): Promise<void> {
    if (!this.admin) throw this.storageUnavailable();
    const pending = await this.prisma.mediaUpload.updateMany({
      where: { ownerId: userId, publicKey, purpose, status: 'pending', expiresAt: { gt: new Date() } }, data: { status: 'processing' },
    });
    if (pending.count === 0) {
      const existing = await this.prisma.mediaUpload.findFirst({ where: { ownerId: userId, publicKey, purpose }, select: { status: true } });
      if (existing?.status === 'ready') return;
      throw new AppError(HttpStatus.BAD_REQUEST, 'media_not_uploaded', 'Ảnh chưa tải xong, đã hết hạn hoặc đang được xử lý');
    }
    const upload = await this.prisma.mediaUpload.findFirstOrThrow({ where: { ownerId: userId, publicKey }, select: { id: true, quarantineKey: true, expectedSize: true } });
    try {
      const object = await this.admin.send(new GetObjectCommand({ Bucket: this.bucket, Key: upload.quarantineKey }));
      const bytes = await object.Body?.transformToByteArray();
      if (!bytes || bytes.byteLength !== upload.expectedSize || bytes.byteLength > MAX_IMAGE_BYTES) throw new Error('size mismatch');
      const image = sharp(Buffer.from(bytes), { limitInputPixels: MAX_IMAGE_PIXELS, failOn: 'error' });
      const metadata = await image.metadata();
      if (!metadata.format || !ALLOWED_INPUT_FORMATS.has(metadata.format)) throw new Error(`unsupported image format: ${metadata.format}`);
      if (!metadata.width || !metadata.height || metadata.width * metadata.height > MAX_IMAGE_PIXELS) throw new Error('invalid image dimensions');
      const cleaned = await image.rotate().webp({ quality: 85 }).toBuffer();
      await this.admin.send(new PutObjectCommand({ Bucket: this.bucket, Key: publicKey, Body: cleaned, ContentType: 'image/webp', CacheControl: 'public, max-age=31536000, immutable' }));
      await this.admin.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: upload.quarantineKey }));
      await this.prisma.mediaUpload.update({ where: { id: upload.id }, data: { status: 'ready', finalizedAt: new Date() } });
    } catch (err) {
      await this.admin.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: upload.quarantineKey })).catch(() => undefined);
      await this.prisma.mediaUpload.update({ where: { id: upload.id }, data: { status: 'rejected' } }).catch(() => undefined);
      this.logger.warn(`Từ chối upload ${upload.id}: ${(err as Error).message}`);
      throw new AppError(HttpStatus.UNSUPPORTED_MEDIA_TYPE, 'invalid_image_content', 'File tải lên không phải ảnh hợp lệ');
    }
  }

  private storageUnavailable() { return new AppError(HttpStatus.SERVICE_UNAVAILABLE, 'storage_unavailable', 'Kho ảnh chưa được cấu hình'); }
}

const PUBLIC_KEY_PATTERN = /^public\/[0-9a-f-]{36}\.webp$/i;
/** Định dạng đầu vào Sharp được phép decode (chặn SVG/GIF/TIFF... dù Sharp đọc được). */
const ALLOWED_INPUT_FORMATS = new Set(['jpeg', 'png', 'webp']);
const CLEANUP_BATCH_SIZE = 100;
/** Chặn vòng lặp vô hạn nếu có lỗi bất thường: tối đa 100 x 100 bản ghi mỗi lần chạy. */
const CLEANUP_MAX_BATCHES = 100;

function startOfUtcDay(now: Date): Date { return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())); }
