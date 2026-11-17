import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsInt, IsString, Min } from 'class-validator';
import { Trim } from '../common/trim.js';

export const IMAGE_TYPES = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/heic': 'heic',
} as const;

export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
/** Chặn ảnh bom (decompression bomb) trước khi re-encode. */
export const MAX_IMAGE_PIXELS = 40_000_000;
/** Tổng dung lượng mà một tài khoản có thể xin URL trong một ngày UTC. */
export const DAILY_UPLOAD_QUOTA_BYTES = 50 * 1024 * 1024;
export const UPLOAD_URL_TTL_SECONDS = 300;

export enum MediaPurpose {
  post = 'post',
  avatar = 'avatar',
  receipt = 'receipt',
}

export class CreateUploadDto {
  @ApiProperty({ enum: MediaPurpose, enumName: 'MediaPurpose' })
  @IsEnum(MediaPurpose)
  purpose: MediaPurpose;

  @ApiProperty({
    enum: Object.keys(IMAGE_TYPES),
    example: 'image/jpeg',
    description: 'Loại ảnh cho phép: jpeg, png, webp, heic',
  })
  @Trim()
  @IsString()
  contentType: string;

  @ApiProperty({
    type: 'integer',
    minimum: 1,
    maximum: MAX_IMAGE_BYTES,
    description: 'Dung lượng file (byte), tối đa 10MB',
  })
  @IsInt()
  @Min(1)
  size: number;
}

export class UploadUrlDto {
  @ApiProperty({ example: 'PUT' }) method: string;
  @ApiProperty({
    description: 'URL có chữ ký, app PUT nguyên file lên URL này',
  })
  uploadUrl: string;
  @ApiProperty({
    description: 'Header bắt buộc khi PUT (phải khớp chữ ký)',
    type: 'object',
    additionalProperties: { type: 'string' },
  })
  headers: Record<string, string>;
  @ApiProperty({ description: 'Khoá ảnh sẽ được công khai sau bước xác minh nội dung' })
  key: string;
  @ApiProperty({ description: 'URL xem ảnh sau khi tải lên xong' })
  publicUrl: string;
  @ApiProperty({ type: 'integer', example: UPLOAD_URL_TTL_SECONDS })
  expiresIn: number;
}
