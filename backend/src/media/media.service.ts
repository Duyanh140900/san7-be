import { randomUUID } from 'node:crypto';
import {
  CreateBucketCommand,
  HeadBucketCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { HttpStatus, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AppError } from '../common/errors.js';
import type { Env } from '../common/env.js';
import {
  IMAGE_TYPES,
  MAX_IMAGE_BYTES,
  UPLOAD_URL_TTL_SECONDS,
  type CreateUploadDto,
  type UploadUrlDto,
} from './media.dto.js';

/** Tải ảnh lên kho S3 (SeaweedFS) bằng URL có chữ ký; key luôn nằm dưới users/{userId}/. */
@Injectable()
export class MediaService implements OnModuleInit {
  private readonly logger = new Logger(MediaService.name);
  private readonly bucket: string;
  private readonly publicUrl: string;
  private readonly enabled: boolean;
  private readonly admin?: S3Client;
  private readonly signer?: S3Client;

  constructor(config: ConfigService<Env, true>) {
    const endpoint = config.get('S3_ENDPOINT', { infer: true });
    const publicUrl = config.get('S3_PUBLIC_URL', { infer: true });
    this.bucket = config.get('S3_BUCKET', { infer: true });
    this.publicUrl = (publicUrl || endpoint).replace(/\/+$/, '');
    this.enabled = Boolean(endpoint);
    if (!this.enabled) return;
    const base = {
      region: config.get('S3_REGION', { infer: true }),
      forcePathStyle: true,
      // SeaweedFS S3 không hiểu checksum CRC32 tự động của AWS SDK và trả BadDigest.
      requestChecksumCalculation: 'WHEN_REQUIRED' as const,
      credentials: {
        accessKeyId: config.get('S3_ACCESS_KEY', { infer: true }),
        secretAccessKey: config.get('S3_SECRET_KEY', { infer: true }),
      },
    };
    // admin gọi qua mạng nội bộ; signer ký theo host mà app bên ngoài truy cập được
    this.admin = new S3Client({ ...base, endpoint });
    this.signer = new S3Client({ ...base, endpoint: this.publicUrl });
  }

  /** Tạo bucket nếu chưa có. Lỗi không làm API dừng (kho file có thể khởi động chậm hơn). */
  async onModuleInit(): Promise<void> {
    if (!this.admin) return;
    try {
      await this.admin.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch {
      try {
        await this.admin.send(new CreateBucketCommand({ Bucket: this.bucket }));
        this.logger.log(`Đã tạo bucket ${this.bucket}`);
      } catch (err) {
        this.logger.warn(
          `Chưa chuẩn bị được bucket ${this.bucket}: ${(err as Error).message}`,
        );
      }
    }
  }

  async createImageUpload(
    userId: string,
    dto: CreateUploadDto,
  ): Promise<UploadUrlDto> {
    if (!this.signer) {
      throw new AppError(
        HttpStatus.SERVICE_UNAVAILABLE,
        'storage_unavailable',
        'Kho ảnh chưa được cấu hình',
      );
    }
    const contentType = dto.contentType.toLowerCase();
    const ext = IMAGE_TYPES[contentType as keyof typeof IMAGE_TYPES];
    if (!ext) {
      throw new AppError(
        HttpStatus.UNSUPPORTED_MEDIA_TYPE,
        'media_type_not_allowed',
        'Chỉ nhận ảnh JPEG, PNG, WebP hoặc HEIC',
      );
    }
    if (dto.size > MAX_IMAGE_BYTES) {
      throw new AppError(
        HttpStatus.PAYLOAD_TOO_LARGE,
        'media_too_large',
        'Ảnh tối đa 10MB',
      );
    }
    const key = `users/${userId}/${dto.purpose}/${randomUUID()}.${ext}`;
    // Content-Type và Content-Length nằm trong chữ ký: PUT sai loại/dung lượng bị kho từ chối
    const uploadUrl = await getSignedUrl(
      this.signer,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: contentType,
        ContentLength: dto.size,
      }),
      {
        expiresIn: UPLOAD_URL_TTL_SECONDS,
        signableHeaders: new Set(['content-type', 'content-length']),
      },
    );
    return {
      method: 'PUT',
      uploadUrl,
      headers: { 'Content-Type': contentType },
      key,
      publicUrl: this.publicUrlFor(key),
      expiresIn: UPLOAD_URL_TTL_SECONDS,
    };
  }

  /** URL xem ảnh của một key. */
  publicUrlFor(key: string): string {
    return `${this.publicUrl}/${this.bucket}/${key}`;
  }

  /** Key phải thuộc về user (dùng khi gắn ảnh vào kèo/hồ sơ, tránh gắn ảnh của người khác). */
  assertOwnedKey(userId: string, key: string): void {
    if (!key.startsWith(`users/${userId}/`) || key.includes('..')) {
      throw new AppError(
        HttpStatus.FORBIDDEN,
        'media_forbidden',
        'Ảnh không thuộc về bạn',
      );
    }
  }

  /** Kiểm tra ảnh đã tải lên, thuộc user và vẫn nằm trong giới hạn trước khi gắn vào kèo. */
  async assertUsablePostMedia(userId: string, keys: string[]): Promise<void> {
    if (keys.length === 0) return;
    if (!this.admin) {
      throw new AppError(
        HttpStatus.SERVICE_UNAVAILABLE,
        'storage_unavailable',
        'Kho ảnh chưa được cấu hình',
      );
    }
    await Promise.all(
      keys.map(async (key) => {
        this.assertOwnedKey(userId, key);
        if (!key.startsWith(`users/${userId}/post/`)) {
          throw new AppError(
            HttpStatus.FORBIDDEN,
            'media_forbidden',
            'Chỉ ảnh tải lên cho kèo mới được gắn vào kèo',
          );
        }
        try {
          const object = await this.admin!.send(
            new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
          );
          const contentType = object.ContentType?.toLowerCase();
          if (!contentType || !(contentType in IMAGE_TYPES)) {
            throw new AppError(
              HttpStatus.UNSUPPORTED_MEDIA_TYPE,
              'media_type_not_allowed',
              'Ảnh tải lên không đúng định dạng cho phép',
            );
          }
          if (
            object.ContentLength === undefined ||
            object.ContentLength > MAX_IMAGE_BYTES
          ) {
            throw new AppError(
              HttpStatus.PAYLOAD_TOO_LARGE,
              'media_too_large',
              'Ảnh tối đa 10MB',
            );
          }
        } catch (err) {
          if (err instanceof AppError) throw err;
          throw new AppError(
            HttpStatus.BAD_REQUEST,
            'media_not_uploaded',
            'Ảnh chưa được tải lên hoặc không còn tồn tại',
          );
        }
      }),
    );
  }
}
