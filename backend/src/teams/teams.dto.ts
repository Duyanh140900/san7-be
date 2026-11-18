import { Trim } from '../common/trim.js';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEnum,
  IsInt,
  Max,
  Min,
  IsOptional,
  IsString,
  IsUUID,
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
  @Trim()
  @IsString()
  @Length(2, 50)
  name: string;

  @ApiProperty({ maxLength: 50, example: 'Cầu Giấy' })
  @Trim()
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

export class TeamDetailDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty() crestColor: string;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
  @ApiProperty({ type: 'integer' }) memberCount: number;
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' }) myRole: TeamRole;
  @ApiProperty({
    type: 'integer',
    description: 'Quỹ tháng mỗi người (VND), 0 = không thu',
  })
  monthlyDue: number;
  @ApiPropertyOptional({ format: 'uuid', description: 'Sân nhà của đội' })
  homePitchId?: string | null;
  @ApiPropertyOptional({ description: 'Chỉ đội trưởng/đội phó thấy' })
  inviteCode?: string;
  @ApiPropertyOptional({ type: String, format: 'date-time' })
  inviteExpiresAt?: Date | null;
}

export class UpdateTeamDto {
  @ApiPropertyOptional({ minLength: 2, maxLength: 50 })
  @IsOptional()
  @Trim()
  @IsString()
  @Length(2, 50)
  name?: string;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @Trim()
  @IsString()
  @Length(1, 50)
  area?: string;

  @ApiPropertyOptional({ enum: TeamLevel, enumName: 'TeamLevel' })
  @IsOptional()
  @IsEnum(TeamLevel)
  level?: TeamLevel;

  @ApiPropertyOptional({ example: '#0066CC' })
  @IsOptional()
  @Matches(/^#[0-9A-Fa-f]{6}$/)
  crestColor?: string;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: 10_000_000 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(10_000_000)
  monthlyDue?: number;

  @ApiPropertyOptional({ format: 'uuid', nullable: true })
  @IsOptional()
  @IsUUID()
  homePitchId?: string | null;
}

export class InviteDto {
  @ApiProperty() inviteCode: string;
  @ApiProperty({ type: String, format: 'date-time' }) inviteExpiresAt: Date;
}

export class TeamMemberDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl: string | null;
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' }) role: TeamRole;
  @ApiProperty({ enum: MemberStatus, enumName: 'MemberStatus' }) status: MemberStatus;
  @ApiPropertyOptional({ type: String, format: 'date-time' }) joinedAt: Date | null;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class UpdateMemberRoleDto {
  @ApiProperty({ enum: ['vice', 'treasurer', 'member'] })
  @IsEnum(TeamRole)
  role: TeamRole;
}
