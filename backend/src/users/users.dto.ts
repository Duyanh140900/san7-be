import { Trim } from '../common/trim.js';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
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
