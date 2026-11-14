import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsEnum,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Trim } from '../common/trim.js';
import {
  AttendanceStatus,
  EventKind,
  Position,
} from '../generated/prisma/enums.js';

export class CreateEventDto {
  @ApiProperty({ enum: EventKind, enumName: 'EventKind' })
  @IsEnum(EventKind)
  kind: EventKind;

  @ApiProperty({ minLength: 1, maxLength: 80, example: 'vs FC Mỹ Đình' })
  @Trim()
  @IsString()
  @Length(1, 80)
  title: string;

  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  startAt: Date;

  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  endAt: Date;

  @ApiPropertyOptional({ maxLength: 120, example: 'Hà Đông Arena, sân 2' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(120)
  location?: string;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(300)
  note?: string;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 40 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(40)
  minPlayers?: number;
}

export class UpdateEventDto extends PartialType(CreateEventDto) {}

export class ListEventsQuery {
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

export class AttendanceCountsDto {
  @ApiProperty({ type: 'integer' }) go: number;
  @ApiProperty({ type: 'integer' }) maybe: number;
  @ApiProperty({ type: 'integer' }) no: number;
  @ApiProperty({ type: 'integer', description: 'Thành viên chưa trả lời' })
  pending: number;
}

export class EventSummaryDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: EventKind, enumName: 'EventKind' }) kind: EventKind;
  @ApiProperty() title: string;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) endAt: Date;
  @ApiPropertyOptional({ type: String }) location?: string | null;
  @ApiPropertyOptional({ type: String }) note?: string | null;
  @ApiPropertyOptional({ type: 'integer' }) minPlayers?: number | null;
  @ApiProperty({ type: AttendanceCountsDto }) counts: AttendanceCountsDto;
  @ApiPropertyOptional({
    enum: AttendanceStatus,
    enumName: 'AttendanceStatus',
    description: 'Câu trả lời của tôi (vắng mặt = chưa trả lời)',
  })
  myStatus?: AttendanceStatus | null;
}

export class AttendeeDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
  @ApiPropertyOptional({
    enum: AttendanceStatus,
    enumName: 'AttendanceStatus',
    description: 'Vắng mặt = chưa trả lời',
  })
  status?: AttendanceStatus | null;
  @ApiPropertyOptional({ type: String }) note?: string | null;
}

export class EventDetailDto extends EventSummaryDto {
  @ApiProperty({ type: [AttendeeDto] }) attendees: AttendeeDto[];
}

export class SetAttendanceDto {
  @ApiProperty({ enum: AttendanceStatus, enumName: 'AttendanceStatus' })
  @IsEnum(AttendanceStatus)
  status: AttendanceStatus;

  @ApiPropertyOptional({ maxLength: 100, example: 'bận việc' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(100)
  note?: string;
}
