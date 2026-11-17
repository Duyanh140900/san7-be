import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MAX_AMOUNT } from '../common/money.js';
import { Trim } from '../common/trim.js';
import { FundType } from '../generated/prisma/enums.js';

export class CreateFundTxDto {
  @ApiProperty({ enum: FundType, enumName: 'FundType' })
  @IsEnum(FundType)
  type: FundType;

  @ApiProperty({
    type: 'integer',
    minimum: 1,
    maximum: MAX_AMOUNT,
    description:
      'Số tiền VND cho MỖI người (thu nhiều người: tổng = amount × số người)',
  })
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT)
  amount: number;

  @ApiProperty({ maxLength: 50, example: 'Quỹ tháng 11' })
  @Trim()
  @IsString()
  @Length(1, 50)
  category: string;

  @ApiPropertyOptional({
    type: [String],
    description:
      'Thu: người nộp (0..n). Chi: người chi (0..1). Phạt: người bị phạt (1..n).',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(60)
  @IsUUID('all', { each: true })
  memberIds?: string[];

  @ApiPropertyOptional({ format: 'uuid', description: 'Gắn với lịch/trận' })
  @IsOptional()
  @IsUUID()
  eventId?: string;

  @ApiPropertyOptional({
    example: '2026-11',
    description: 'Kỳ quỹ tháng (chỉ với khoản thu quỹ tháng)',
  })
  @IsOptional()
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/)
  period?: string;

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(200)
  note?: string;

  @ApiPropertyOptional({ description: 'Khoá ảnh biên lai đã finalize cho đúng đội' })
  @IsOptional()
  @IsString()
  @Matches(/^public\/[0-9a-f-]{36}\.webp$/i)
  receiptKey?: string;

  @ApiPropertyOptional({
    description: 'Phạt: đã nộp chưa (mặc định chưa). Thu/chi luôn là đã nộp.',
  })
  @IsOptional()
  @IsBoolean()
  paid?: boolean;
}

export class FinesQuery {
  @ApiPropertyOptional({
    example: '2026-11',
    description: 'Tháng YYYY-MM, mặc định tháng này',
  })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}$/)
  period?: string;
}

export class ListFundTxQuery {
  @ApiPropertyOptional({ enum: FundType, enumName: 'FundType' })
  @IsOptional()
  @IsEnum(FundType)
  type?: FundType;

  @ApiPropertyOptional({ description: 'Con trỏ trang trước (nextCursor)' })
  @IsOptional()
  @IsString()
  cursor?: string;

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

export class PersonRefDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
}

export class EventRefDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
}

export class FundTxDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: FundType, enumName: 'FundType' }) type: FundType;
  @ApiProperty({ type: 'integer' }) amount: number;
  @ApiProperty() category: string;
  @ApiPropertyOptional({ type: PersonRefDto }) member?: PersonRefDto | null;
  @ApiPropertyOptional({ type: EventRefDto }) event?: EventRefDto | null;
  @ApiPropertyOptional({ type: String }) period?: string | null;
  @ApiPropertyOptional({ type: String }) note?: string | null;
  @ApiPropertyOptional({ type: String }) receiptUrl?: string | null;
  @ApiProperty() paid: boolean;
  @ApiProperty({ type: PersonRefDto }) createdBy: PersonRefDto;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class FinesDto {
  @ApiProperty({ example: '2026-11' }) period: string;
  @ApiProperty({
    type: 'integer',
    description: 'Tổng tiền phạt đã ghi trong tháng (VND)',
  })
  total: number;
  @ApiProperty({ type: 'integer', description: 'Phần chưa nộp (VND)' })
  unpaid: number;
  @ApiProperty({ type: [FundTxDto], description: 'Khoản phạt mới nhất trước' })
  items: FundTxDto[];
}

export class FundTxPageDto {
  @ApiProperty({ type: [FundTxDto] }) items: FundTxDto[];
  @ApiPropertyOptional({ type: String }) nextCursor?: string | null;
}

export class DuesProgressDto {
  @ApiProperty({ example: '2026-11' }) period: string;
  @ApiProperty({ type: 'integer' }) amount: number;
  @ApiProperty({ type: 'integer' }) paidCount: number;
  @ApiProperty({ type: 'integer' }) totalCount: number;
  @ApiProperty({ type: [PersonRefDto] }) unpaid: PersonRefDto[];
}

export class FundSummaryDto {
  @ApiProperty({ type: 'integer' }) balance: number;
  @ApiProperty({ type: 'integer', description: 'Thu trong tháng (giờ VN)' })
  monthIncome: number;
  @ApiProperty({ type: 'integer', description: 'Chi trong tháng (giờ VN)' })
  monthExpense: number;
  @ApiProperty({ type: 'integer', description: 'Tổng tiền phạt chưa nộp' })
  unpaidFines: number;
  @ApiPropertyOptional({
    type: DuesProgressDto,
    description: 'Vắng mặt nếu đội không thu quỹ tháng',
  })
  dues?: DuesProgressDto | null;
  @ApiProperty({ type: [FundTxDto], description: '5 khoản gần nhất' })
  recent: FundTxDto[];
}

export class FineRuleDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty({ type: 'integer' }) amount: number;
}

export class CreateFineRuleDto {
  @ApiProperty({ maxLength: 50, example: 'Đi muộn' })
  @Trim()
  @IsString()
  @Length(1, 50)
  name: string;

  @ApiProperty({ type: 'integer', minimum: 1000, maximum: 10_000_000 })
  @IsInt()
  @Min(1000)
  @Max(10_000_000)
  amount: number;
}
