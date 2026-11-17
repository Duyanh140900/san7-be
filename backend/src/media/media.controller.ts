import { Body, Controller, Get, Header, Param, ParseUUIDPipe, Post, StreamableFile } from '@nestjs/common';
import { ApiBearerAuth, ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import { Public } from '../common/auth.decorators.js';
import { CreateUploadDto, UploadUrlDto } from './media.dto.js';
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

  /** Chỉ trả ảnh đã re-encode; browser không được MIME-sniff nội dung. */
  @Public()
  @Get('public/:id')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOkResponse({ description: 'Ảnh WebP đã được xác minh' })
  readPublic(@Param('id', ParseUUIDPipe) id: string): Promise<StreamableFile> {
    return this.media.readPublicImage(id);
  }
}
