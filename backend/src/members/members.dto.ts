import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum } from 'class-validator';
import { MemberStatus, Position, TeamRole } from '../generated/prisma/enums.js';

export class MemberDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
  @ApiPropertyOptional({ type: 'integer' }) shirtNumber?: number | null;
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' }) role: TeamRole;
  @ApiProperty({ enum: MemberStatus, enumName: 'MemberStatus' })
  status: MemberStatus;
  @ApiPropertyOptional({ type: String, format: 'date-time' })
  joinedAt?: Date | null;
  @ApiProperty({
    type: String,
    format: 'date-time',
    description: 'Lúc gửi yêu cầu / được thêm',
  })
  requestedAt: Date;
}

export class MemberListDto {
  @ApiProperty({ type: [MemberDto] }) active: MemberDto[];
  @ApiProperty({
    type: [MemberDto],
    description: 'Yêu cầu chờ duyệt (chỉ đội trưởng/đội phó thấy)',
  })
  pending: MemberDto[];
}

export class ChangeRoleDto {
  @ApiProperty({ enum: TeamRole, enumName: 'TeamRole' })
  @IsEnum(TeamRole)
  role: TeamRole;
}
