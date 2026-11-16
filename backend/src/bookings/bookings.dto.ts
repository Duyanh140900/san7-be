import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Trim } from '../common/trim.js';
import { BookingStatus } from '../generated/prisma/enums.js';

export class CreateBookingDto {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  pitchId: string;

  @ApiProperty({
    type: String,
    format: 'date-time',
    description: 'Giờ bắt đầu, phải đúng một khung giờ của sân',
  })
  @Type(() => Date)
  @IsDate()
  startAt: Date;

  @ApiPropertyOptional({ maxLength: 200, description: 'Ghi chú cho chủ sân' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(200)
  note?: string;
}

export class RescheduleBookingDto {
  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  startAt: Date;
}

export class ListBookingsQuery {
  @ApiPropertyOptional({ enum: ['upcoming', 'past'], default: 'upcoming' })
  @IsOptional()
  @IsIn(['upcoming', 'past'])
  scope?: 'upcoming' | 'past';

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 1,
    maximum: 50,
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

export class BookingPitchDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty() district: string;
  @ApiProperty() address: string;
  @ApiProperty({ type: 'number' }) lat: number;
  @ApiProperty({ type: 'number' }) lng: number;
}

export class BookingDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({
    example: 'SC-7Q2K',
    description: 'Mã đưa cho quầy khi nhận sân',
  })
  code: string;
  @ApiProperty({ enum: BookingStatus, enumName: 'BookingStatus' })
  status: BookingStatus;
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty({ type: BookingPitchDto }) pitch: BookingPitchDto;
  @ApiProperty({ type: 'integer' }) courtNo: number;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) endAt: Date;
  @ApiProperty({ type: 'integer', description: 'Tiền sân (VND), trả tại sân' })
  price: number;
  @ApiProperty({
    type: 'integer',
    description: 'Tiền cọc (VND), 0 ở bản trả tại sân',
  })
  deposit: number;
  @ApiPropertyOptional({ type: String }) note?: string | null;
  @ApiPropertyOptional({
    type: String,
    format: 'date-time',
    description: 'Hết hạn giữ chỗ (chỉ khi đang giữ)',
  })
  heldUntil?: Date | null;
  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    description: 'Kèo đang gắn với lượt đặt này',
  })
  postId?: string | null;
  @ApiPropertyOptional({
    type: String,
    format: 'uuid',
    description: 'Lịch đội sinh ra khi xác nhận',
  })
  eventId?: string | null;
  @ApiProperty({
    description: 'Còn đổi giờ/huỷ được (chưa tới giờ, không gắn với kèo)',
  })
  canChange: boolean;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}
