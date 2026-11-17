import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsDate, IsOptional, IsInt, Matches, Max, Min } from 'class-validator';
import { CreatePostDto } from '../posts/posts.dto.js';

export class CreatePostScheduleDto extends CreatePostDto {
  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  scheduledAt: Date;

  @ApiPropertyOptional({ default: false, description: 'Đăng lại mỗi tuần, đồng thời dời giờ đá thêm 7 ngày.' })
  @IsOptional()
  @IsBoolean()
  repeatWeekly?: boolean;
}

export class UpdatePostScheduleDto {
  @ApiPropertyOptional({ example: '19:30', description: 'Giờ đăng mới theo giờ Việt Nam' })
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  time?: string;

  @ApiPropertyOptional({ minimum: 0, maximum: 6, description: '0 là Chủ nhật, 1 là Thứ hai' })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(6)
  weekday?: number;

  @ApiPropertyOptional({ type: String, format: 'date-time', description: 'Tạm dừng đến thời điểm này; null để tiếp tục' })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  pausedUntil?: Date | null;
}

export class PostScheduleDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty({ format: 'date-time' }) scheduledAt: Date;
  @ApiProperty() repeatWeekly: boolean;
  @ApiProperty({ enum: ['scheduled', 'cancelled'] }) status: 'scheduled' | 'cancelled';
  @ApiPropertyOptional({ type: String, format: 'uuid' }) publishedPostId: string | null;
  @ApiPropertyOptional({ type: String, format: 'date-time' }) pausedUntil: Date | null;
  @ApiProperty({ type: CreatePostDto }) post: CreatePostDto;
}
