import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Trim } from '../common/trim.js';
import { ReactionKind } from '../generated/prisma/enums.js';

const PAGE_SIZE = 30;

export class CreateCommentDto {
  @ApiProperty({ maxLength: 1000, example: 'Đội mình nhận kèo nhé!' })
  @Trim()
  @IsString()
  @MaxLength(1000)
  body: string;
}

export class SetReactionDto {
  @ApiProperty({ enum: ReactionKind, enumName: 'ReactionKind' })
  @IsEnum(ReactionKind)
  kind: ReactionKind;
}

export class CursorPageQuery {
  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 1,
    maximum: 50,
    default: PAGE_SIZE,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

export class ListReactionsQuery extends CursorPageQuery {
  @ApiPropertyOptional({ enum: ReactionKind, enumName: 'ReactionKind' })
  @IsOptional()
  @IsEnum(ReactionKind)
  kind?: ReactionKind;
}

export class CommentAuthorDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
}

export class CommentDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) postId: string;
  @ApiProperty() body: string;
  @ApiProperty({ type: CommentAuthorDto }) author: CommentAuthorDto;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) updatedAt: Date;
}

export class CommentPageDto {
  @ApiProperty({ type: [CommentDto] }) items: CommentDto[];
  @ApiPropertyOptional({ type: String }) nextCursor?: string;
}

export class ReactionCountDto {
  @ApiProperty({ enum: ReactionKind, enumName: 'ReactionKind' })
  kind: ReactionKind;
  @ApiProperty({ type: 'integer' }) count: number;
}

export class ReactionUserDto extends CommentAuthorDto {
  @ApiProperty({ enum: ReactionKind, enumName: 'ReactionKind' })
  kind: ReactionKind;
  @ApiProperty({ type: String, format: 'date-time' }) reactedAt: Date;
}

export class ReactionPageDto {
  @ApiProperty({ type: [ReactionCountDto] }) counts: ReactionCountDto[];
  @ApiPropertyOptional({ enum: ReactionKind, enumName: 'ReactionKind' })
  myKind?: ReactionKind;
  @ApiProperty({ type: [ReactionUserDto] }) items: ReactionUserDto[];
  @ApiPropertyOptional({ type: String }) nextCursor?: string;
}
