import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';
import {
  MemberStatus,
  TeamLevel,
  TeamRole,
} from '../generated/prisma/enums.js';

export class CreateTeamDto {
  @ApiProperty({ minLength: 2, maxLength: 50, example: 'FC Cầu Giấy' })
  @IsString()
  @Length(2, 50)
  name: string;

  @ApiProperty({ maxLength: 50, example: 'Cầu Giấy' })
  @IsString()
  @Length(1, 50)
  area: string;

  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' })
  @IsEnum(TeamLevel)
  level: TeamLevel;

  @ApiPropertyOptional({ example: '#0066CC' })
  @IsOptional()
  @Matches(/^#[0-9A-Fa-f]{6}$/)
  crestColor?: string;
}

export class JoinTeamDto {
  @ApiProperty({ example: 'CG7-2486' })
  @IsString()
  @MaxLength(20)
  code: string;
}

export class TeamInvitePreviewDto {
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty() name: string;
  @ApiProperty() crestColor: string;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
  @ApiProperty({ type: 'integer' }) memberCount: number;
}

export class TeamDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty() crestColor: string;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
  @ApiProperty() inviteCode: string;
  @ApiPropertyOptional({ type: String, format: 'date-time' })
  inviteExpiresAt: Date | null;
}

export class MembershipDto {
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty() teamName: string;
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' }) role: TeamRole;
  @ApiProperty({ enum: MemberStatus, enumName: 'MemberStatus' })
  status: MemberStatus;
}
