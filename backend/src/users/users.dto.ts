import { Trim } from '../common/trim.js';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import {
  MemberStatus,
  Platform,
  Position,
  TeamLevel,
  TeamRole,
} from '../generated/prisma/enums.js';

export class BookingSummaryQuery {
  @ApiPropertyOptional({ type: 'integer', example: 2026 }) @IsOptional() @Type(() => Number) @IsInt() @Min(2020) @Max(2100) year?: number;
}
export class BookingSummaryDto {
  @ApiProperty() count: number;
  @ApiProperty() hours: number;
  @ApiProperty({ type: 'integer' }) teamPaid: number;
  @ApiPropertyOptional({ type: Object }) topPitch: { name: string; count: number } | null;
}

export class MyTeamDto {
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty() name: string;
  @ApiProperty({ example: '#0066CC' }) crestColor: string;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' }) role: TeamRole;
  @ApiProperty({ enum: MemberStatus, enumName: 'MemberStatus' })
  status: MemberStatus;
}

export class PlayerStatsDto {
  @ApiProperty() goals: number;
  @ApiProperty() assists: number;
  @ApiProperty() mvps: number;
  @ApiProperty() matches: number;
}

export class MeDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() email: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position: Position | null;
  @ApiPropertyOptional({ type: 'integer' }) shirtNumber: number | null;
  @ApiPropertyOptional({ type: String }) area: string | null;
  @ApiProperty({ description: 'Đã điền hồ sơ cầu thủ (bước 2 màn 12)' })
  profileCompleted: boolean;
  @ApiProperty({ type: [MyTeamDto] }) teams: MyTeamDto[];
  @ApiProperty({ type: () => PlayerStatsDto }) stats: PlayerStatsDto;
}

export class NotificationSettingsDto {
  @ApiProperty() matchUpdates: boolean;
  @ApiProperty() teamActivity: boolean;
  @ApiProperty() community: boolean;
}

export class UpdateNotificationSettingsDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean() matchUpdates?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() teamActivity?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() community?: boolean;
}

export class UpdateMeDto {
  @ApiPropertyOptional({ minLength: 1, maxLength: 50 })
  @IsOptional()
  @Trim()
  @IsString()
  @Length(1, 50)
  name?: string;

  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  @IsOptional()
  @IsEnum(Position)
  position?: Position;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: 99 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(99)
  shirtNumber?: number;

  @ApiPropertyOptional({ maxLength: 50, example: 'Cầu Giấy' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(50)
  area?: string;

  @ApiPropertyOptional({ description: 'Khoá ảnh đại diện (purpose=avatar) đã PUT lên quarantine; server xác minh rồi cập nhật avatarUrl', example: 'public/00000000-0000-4000-8000-000000000000.webp' })
  @IsOptional()
  @IsString()
  avatarKey?: string;
}

export class RegisterDeviceDto {
  @ApiProperty()
  @IsString()
  @Length(10, 4096)
  fcmToken: string;

  @ApiProperty({ enum: Platform, enumName: 'Platform' })
  @IsEnum(Platform)
  platform: Platform;
}

export class PublicPlayerDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' }) position: Position | null;
  @ApiPropertyOptional({ type: 'integer' }) shirtNumber: number | null;
  @ApiPropertyOptional({ type: Object }) team: { id: string; name: string; crestColor: string } | null;
  @ApiProperty({ type: PlayerStatsDto }) stats: PlayerStatsDto;
  @ApiProperty({ type: [Object] }) recentMatches: { matchId: string; startAt: Date; goals: number; assists: number; mvp: boolean }[];
  @ApiPropertyOptional({ type: Object }) headToHead?: { played: number; wins: number; draws: number; losses: number } | null;
}
