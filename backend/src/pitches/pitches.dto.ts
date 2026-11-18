import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsDate,
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Trim } from '../common/trim.js';

/** Tiện ích của sân (khoá cố định, app tự đổi sang chữ). */
export const AMENITIES = [
  'light',
  'new_turf',
  'parking',
  'water',
  'locker',
] as const;
export type Amenity = (typeof AMENITIES)[number];

export class PitchSlotDto {
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) endAt: Date;
  @ApiProperty({ type: 'integer', description: 'Giá khung giờ (VND)' })
  price: number;
  @ApiProperty({ type: 'integer', description: 'Số sân 7 còn trống' })
  free: number;
  @ApiProperty({ type: 'integer', description: 'Tổng số sân 7' })
  total: number;
  @ApiProperty({ description: 'Còn sân trống và chưa tới giờ' })
  available: boolean;
}

export class PitchDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty() district: string;
  @ApiProperty() address: string;
  @ApiProperty({ type: 'number', example: 20.9806 }) lat: number;
  @ApiProperty({ type: 'number', example: 105.7882 }) lng: number;
  @ApiPropertyOptional({
    type: 'integer',
    description: 'Khoảng cách tới vị trí truyền lên (mét)',
  })
  distanceM?: number;
  @ApiProperty({
    type: [String],
    enum: AMENITIES,
    description: 'light, new_turf, parking, water, locker',
  })
  amenities: string[];
  @ApiProperty({ type: 'integer' }) courtsCount: number;
  @ApiProperty({ type: 'integer', description: 'Phút mỗi trận' })
  slotMinutes: number;
  @ApiPropertyOptional({ type: String }) phone?: string | null;
  @ApiProperty({ type: String, example: '2026-11-22' }) date: string;
  @ApiProperty({ type: [PitchSlotDto] }) slots: PitchSlotDto[];
  @ApiProperty({
    type: 'integer',
    description: 'Số khung giờ còn trống trong ngày',
  })
  freeSlots: number;
  @ApiPropertyOptional({
    type: 'integer',
    description: 'Giá thấp nhất trong các khung còn trống',
  })
  minPrice?: number;
}

export class PitchListDto {
  @ApiProperty({ type: [PitchDto] }) items: PitchDto[];
}

export class FreePitchSlotDto {
  @ApiProperty({ format: 'uuid' }) pitchId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: 'number', description: 'Khoảng cách km' }) distanceKm?: number;
  @ApiProperty({ type: 'number', description: 'Điểm đánh giá trung bình' }) rating: number;
  @ApiProperty({ type: String, format: 'date-time' }) slotStart: Date;
}

export class FreePitchSlotsQuery {
  @ApiPropertyOptional({ type: 'number' }) @IsOptional() @Type(() => Number) @IsNumber() @Min(-90) @Max(90) lat?: number;
  @ApiPropertyOptional({ type: 'number' }) @IsOptional() @Type(() => Number) @IsNumber() @Min(-180) @Max(180) lng?: number;
  @ApiPropertyOptional({ type: String, format: 'date-time', description: 'Mặc định từ thời điểm hiện tại' })
  @IsOptional() @Type(() => Date) @IsDate() from?: Date;
  @ApiPropertyOptional({ type: String, format: 'date-time', description: 'Mặc định hết tối nay (giờ VN)' })
  @IsOptional() @Type(() => Date) @IsDate() to?: Date;
}

export class CreatePitchReviewDto {
  @ApiProperty() @IsInt() @Min(1) @Max(5) stars: number;
  @ApiProperty() @IsInt() @Min(1) @Max(5) turf: number;
  @ApiProperty() @IsInt() @Min(1) @Max(5) lighting: number;
  @ApiProperty() @IsInt() @Min(1) @Max(5) lockerRoom: number;
  @ApiProperty() @IsInt() @Min(1) @Max(5) ownerPrice: number;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @IsString({ each: true }) @MaxLength(30, { each: true }) tags?: string[];
  @ApiPropertyOptional({ maxLength: 500 }) @IsOptional() @Trim() @IsString() @MaxLength(500) comment?: string;
  @ApiPropertyOptional({ format: 'uuid' }) @IsOptional() @IsUUID() bookingId?: string;
}

export class PitchReviewDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() stars: number;
  @ApiProperty() turf: number;
  @ApiProperty() lighting: number;
  @ApiProperty() lockerRoom: number;
  @ApiProperty() ownerPrice: number;
  @ApiProperty({ type: [String] }) tags: string[];
  @ApiPropertyOptional({ type: String }) comment: string | null;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class PitchListQuery {
  @ApiPropertyOptional({ type: 'number', example: 20.98 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @ApiPropertyOptional({ type: 'number', example: 105.79 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;

  @ApiPropertyOptional({
    type: 'number',
    minimum: 0.5,
    maximum: 50,
    description: 'Bán kính tìm quanh (lat, lng); mặc định 15 km',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.5)
  @Max(50)
  radiusKm?: number;

  @ApiPropertyOptional({ maxLength: 60, description: 'Tên sân, quận, đường' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(60)
  q?: string;

  @ApiPropertyOptional({
    type: String,
    example: '2026-11-22',
    description: 'Ngày (giờ VN), mặc định hôm nay',
  })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date?: string;

  @ApiPropertyOptional({
    type: String,
    example: '19:00',
    description: 'Chỉ lấy sân còn trống khung giờ bắt đầu này',
  })
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/)
  at?: string;

  @ApiPropertyOptional({ enum: AMENITIES })
  @IsOptional()
  @IsIn(AMENITIES)
  amenity?: Amenity;

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

export class PitchDetailQuery {
  @ApiPropertyOptional({ type: String, example: '2026-11-22' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date?: string;

  @ApiPropertyOptional({ type: 'number' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @ApiPropertyOptional({ type: 'number' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;
}
