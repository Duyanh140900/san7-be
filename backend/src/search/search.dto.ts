import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class SearchQuery {
  @ApiProperty({ minLength: 1, maxLength: 100 })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  q: string;

  @ApiPropertyOptional({ enum: ['all', 'teams', 'pitches', 'posts', 'players'], default: 'all' })
  @IsOptional()
  @IsEnum(['all', 'teams', 'pitches', 'posts', 'players'])
  type?: 'all' | 'teams' | 'pitches' | 'posts' | 'players';
}

export class SearchItemDto {
  @ApiProperty() id: string;
  @ApiProperty({ enum: ['teams', 'pitches', 'posts', 'players'] }) kind: 'teams' | 'pitches' | 'posts' | 'players';
  @ApiProperty() title: string;
  @ApiPropertyOptional({ type: String }) subtitle?: string | null;
  @ApiPropertyOptional({ type: String }) imageUrl?: string | null;
}

export class SearchGroupDto {
  @ApiProperty({ enum: ['teams', 'pitches', 'posts', 'players'] }) kind: 'teams' | 'pitches' | 'posts' | 'players';
  @ApiProperty() count: number;
  @ApiProperty({ type: [SearchItemDto] }) items: SearchItemDto[];
}

export class SearchResponseDto {
  @ApiProperty({ type: [SearchGroupDto] }) groups: SearchGroupDto[];
}

export class TrendingSearchDto {
  @ApiProperty() label: string;
  @ApiProperty() query: string;
}
