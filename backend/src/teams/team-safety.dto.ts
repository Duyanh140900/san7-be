import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';
import { Trim } from '../common/trim.js';
export class CreateTeamReportDto {
  @ApiProperty({ format: 'uuid' }) @IsUUID() reportedTeamId: string;
  @ApiPropertyOptional({ format: 'uuid' }) @IsOptional() @IsUUID() matchId?: string;
  @ApiProperty({ maxLength: 80 }) @Trim() @IsString() @MaxLength(80) reason: string;
  @ApiPropertyOptional({ maxLength: 1000 }) @IsOptional() @Trim() @IsString() @MaxLength(1000) description?: string;
  @ApiPropertyOptional({ type: [String], maxItems: 4 }) @IsOptional() @IsArray() @ArrayMaxSize(4) @IsString({ each: true }) imageKeys?: string[];
}
export class TeamSafetyDto { @ApiProperty() success: boolean; }
