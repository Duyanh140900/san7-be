import { Body, Controller, Get, Header, HttpCode, Param, ParseUUIDPipe, Post, StreamableFile } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import { Public } from '../common/auth.decorators.js';
import { CreateUploadDto, FinalizedMediaDto, FinalizeUploadDto, UploadUrlDto } from './media.dto.js';
import { MediaService } from './media.service.js';

/** Xin URL có chữ ký để app tải ảnh thẳng lên kho S3. Lỗi: 413 media_too_large, 415 media_type_not_allowed, 503 storage_unavailable. */
@ApiTags('media')
@ApiBearerAuth()
@Controller('media')
export class MediaController {
  constructor(private readonly media: MediaService) {}

  @Post('uploads')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiCreatedResponse({ type: UploadUrlDto })
  createUpload(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateUploadDto,
  ): Promise<UploadUrlDto> {
    return this.media.createImageUpload(user.userId, dto);
  }

  /** Hoàn tất upload avatar/receipt: xác minh nội dung và re-encode. Lỗi: 400 media_not_uploaded, 403 media_forbidden, 415 invalid_image_content. */
  @Post('uploads/finalize')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOkResponse({ type: FinalizedMediaDto })
  finalize(@CurrentUser() user: AuthUser, @Body() dto: FinalizeUploadDto): Promise<FinalizedMediaDto> {
    return this.media.finalizeUpload(user.userId, dto.key);
  }

  /** Biên lai quỹ: cần đăng nhập và là thành viên active của đội. Lỗi: 403 media_forbidden, 404 media_not_found. */
  @Get('receipts/:id')
  @Header('X-Content-Type-Options', 'nosniff')
  @Header('Cache-Control', 'private, no-store')
  @ApiOkResponse({ description: 'Ảnh WebP biên lai đã được xác minh' })
  readReceipt(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string): Promise<StreamableFile> {
    return this.media.readReceipt(user.userId, id);
  }

  /** Chỉ trả ảnh post/avatar đã re-encode; browser không được MIME-sniff nội dung. */
  @Public()
  @Get('public/:id')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOkResponse({ description: 'Ảnh WebP post/avatar đã được xác minh (biên lai không phục vụ ở đây)' })
  readPublic(@Param('id', ParseUUIDPipe) id: string): Promise<StreamableFile> {
    return this.media.readPublicImage(id);
  }
}
