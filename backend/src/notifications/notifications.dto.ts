import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { NotificationCategory } from '../generated/prisma/enums.js';

export class NotificationPayloadDto {
  @ApiPropertyOptional({ format: 'uuid' }) postId?: string;
  @ApiPropertyOptional({ format: 'uuid' }) requestId?: string;
  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Đội của người nhận mà thông báo liên quan',
  })
  teamId?: string;
  @ApiPropertyOptional({ format: 'uuid' }) matchId?: string;
  @ApiPropertyOptional({ format: 'uuid' }) eventId?: string;
  @ApiPropertyOptional({ format: 'uuid' }) bookingId?: string;
}

export class NotificationDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ example: 'request.received' }) type: string;
  @ApiProperty({ enum: NotificationCategory, enumName: 'NotificationCategory' })
  category: NotificationCategory;
  @ApiProperty() title: string;
  @ApiProperty() body: string;
  @ApiProperty({ type: NotificationPayloadDto })
  payload: NotificationPayloadDto;
  @ApiProperty() read: boolean;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class NotificationPageDto {
  @ApiProperty({ type: [NotificationDto] }) items: NotificationDto[];
  @ApiPropertyOptional({
    type: String,
    description: 'Truyền lại để lấy trang sau',
  })
  nextCursor?: string;
  @ApiProperty({ type: 'integer' }) unreadCount: number;
}

export class UnreadCountDto {
  @ApiProperty({ type: 'integer' }) count: number;
}

export class ListNotificationsQuery {
  @ApiPropertyOptional({
    enum: NotificationCategory,
    enumName: 'NotificationCategory',
  })
  @IsOptional()
  @IsEnum(NotificationCategory)
  category?: NotificationCategory;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 1,
    maximum: 50,
    default: 30,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

export class MarkReadDto {
  @ApiPropertyOptional({
    type: [String],
    description: 'Vắng = đánh dấu tất cả đã đọc',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsUUID('all', { each: true })
  ids?: string[];
}
