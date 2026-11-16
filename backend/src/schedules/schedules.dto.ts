import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsDate, IsOptional } from 'class-validator';
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

export class UpdatePostScheduleDto extends CreatePostScheduleDto {}

export class PostScheduleDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty({ format: 'date-time' }) scheduledAt: Date;
  @ApiProperty() repeatWeekly: boolean;
  @ApiProperty({ enum: ['scheduled', 'cancelled'] }) status: 'scheduled' | 'cancelled';
  @ApiPropertyOptional({ type: String, format: 'uuid' }) publishedPostId: string | null;
  @ApiProperty({ type: CreatePostDto }) post: CreatePostDto;
}
