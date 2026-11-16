import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Trim } from '../common/trim.js';
import { MatchStatus, Position } from '../generated/prisma/enums.js';
import { TeamBriefDto } from '../posts/posts.dto.js';
import { REVIEW_TAGS } from './match-rules.js';

// ---------- Đầu vào ----------

export class SetResultDto {
  @ApiProperty({ type: 'integer', minimum: 0, maximum: 99 })
  @IsInt()
  @Min(0)
  @Max(99)
  homeScore: number;

  @ApiProperty({ type: 'integer', minimum: 0, maximum: 99 })
  @IsInt()
  @Min(0)
  @Max(99)
  awayScore: number;
}

export class PlayerStatInput {
  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  userId: string;

  @ApiProperty({ type: 'integer', minimum: 0, maximum: 30 })
  @IsInt()
  @Min(0)
  @Max(30)
  goals: number;

  @ApiProperty({ type: 'integer', minimum: 0, maximum: 30 })
  @IsInt()
  @Min(0)
  @Max(30)
  assists: number;
}

export class SetStatsDto {
  @ApiProperty({
    type: [PlayerStatInput],
    description:
      'Số bàn, kiến tạo của cầu thủ đội mình. Thay toàn bộ số liệu cũ của đội.',
  })
  @IsArray()
  @ArrayMaxSize(30)
  @ValidateNested({ each: true })
  @Type(() => PlayerStatInput)
  players: PlayerStatInput[];

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Cầu thủ hay nhất của đội mình',
  })
  @IsOptional()
  @IsUUID()
  mvpUserId?: string;
}

export class SubmitReviewDto {
  @ApiProperty({
    type: 'integer',
    minimum: 1,
    maximum: 5,
    description: 'Uy tín, đúng giờ',
  })
  @IsInt()
  @Min(1)
  @Max(5)
  reputation: number;

  @ApiProperty({ type: 'integer', minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  fairplay: number;

  @ApiProperty({
    type: [String],
    enum: REVIEW_TAGS,
    description: 'on_time, good_play, friendly, fair_pay, full_squad',
  })
  @IsArray()
  @ArrayMaxSize(REVIEW_TAGS.length)
  @ArrayUnique()
  @IsIn(REVIEW_TAGS, { each: true })
  tags: string[];

  @ApiPropertyOptional({ maxLength: 200 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(200)
  comment?: string;
}

// ---------- Đầu ra ----------

export class MatchPlayerDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
  @ApiProperty({ type: 'integer' }) goals: number;
  @ApiProperty({ type: 'integer' }) assists: number;
  @ApiProperty() mvp: boolean;
}

export class MyReviewDto {
  @ApiProperty({ type: 'integer' }) reputation: number;
  @ApiProperty({ type: 'integer' }) fairplay: number;
  @ApiProperty({ type: [String] }) tags: string[];
  @ApiPropertyOptional({ type: String }) comment?: string | null;
}

export const RESULT_STATES = [
  'none',
  'awaiting_opponent',
  'awaiting_me',
  'confirmed',
] as const;

export class MatchDetailDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) endAt: Date;
  @ApiPropertyOptional({ type: String }) location?: string | null;
  @ApiProperty({ enum: MatchStatus, enumName: 'MatchStatus' })
  status: MatchStatus;
  @ApiProperty({ type: TeamBriefDto }) homeTeam: TeamBriefDto;
  @ApiProperty({ type: TeamBriefDto }) awayTeam: TeamBriefDto;
  @ApiProperty({ format: 'uuid', description: 'Đội tôi đang xem trận này' })
  myTeamId: string;
  @ApiPropertyOptional({ type: 'integer' }) homeScore?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) awayScore?: number | null;
  @ApiProperty({
    enum: RESULT_STATES,
    description:
      'none: chưa ai nhập; awaiting_opponent: đội tôi đã nhập, chờ đội kia; awaiting_me: đội kia đã nhập, chờ tôi; confirmed: hai bên đã chốt',
  })
  resultState: (typeof RESULT_STATES)[number];
  @ApiProperty({
    description: 'Đã kết thúc giờ đá (được nhập kết quả, thống kê, đánh giá)',
  })
  ended: boolean;
  @ApiProperty({
    description: 'Tôi (đội trưởng/phó) nhập hoặc sửa được tỉ số',
  })
  canReport: boolean;
  @ApiProperty({
    description: 'Tôi (đội trưởng/phó) nhập được thống kê và đánh giá',
  })
  canEdit: boolean;
  @ApiPropertyOptional({
    type: 'integer',
    description: 'Tiền sân đã chốt (VND)',
  })
  pitchPrice?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) ratioWin?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) ratioLose?: number | null;
  @ApiPropertyOptional({
    type: 'integer',
    description: 'Tiền sân đội tôi đã bị trừ vào quỹ sau khi chốt tỉ số',
  })
  myFee?: number | null;
  @ApiProperty({
    type: [MatchPlayerDto],
    description: 'Thành viên đội tôi kèm số liệu',
  })
  roster: MatchPlayerDto[];
  @ApiPropertyOptional({ type: MyReviewDto }) myReview?: MyReviewDto;
  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Lịch trận trong đội tôi',
  })
  eventId?: string | null;
}

// ---------- Hồ sơ đội ----------

export class TeamRecordDto {
  @ApiProperty({ type: 'integer' }) played: number;
  @ApiProperty({ type: 'integer' }) wins: number;
  @ApiProperty({ type: 'integer' }) draws: number;
  @ApiProperty({ type: 'integer' }) losses: number;
  @ApiProperty({ type: 'integer' }) goalsFor: number;
  @ApiProperty({ type: 'integer' }) goalsAgainst: number;
  @ApiProperty({
    type: [String],
    enum: ['W', 'D', 'L'],
    description: '5 trận gần nhất, mới nhất đứng đầu',
  })
  form: string[];
}

export class TagCountDto {
  @ApiProperty() tag: string;
  @ApiProperty({ type: 'integer' }) count: number;
}

export class ReviewItemDto {
  @ApiProperty({ type: TeamBriefDto }) fromTeam: TeamBriefDto;
  @ApiProperty({ type: 'integer' }) reputation: number;
  @ApiProperty({ type: 'integer' }) fairplay: number;
  @ApiPropertyOptional({ type: String }) comment?: string | null;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class RecentMatchDto {
  @ApiProperty({ format: 'uuid' }) matchId: string;
  @ApiProperty({ type: TeamBriefDto }) opponent: TeamBriefDto;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: 'integer' }) goalsFor: number;
  @ApiProperty({ type: 'integer' }) goalsAgainst: number;
  @ApiProperty({ enum: ['W', 'D', 'L'] }) outcome: string;
}

export class TeamProfileDto {
  @ApiProperty({ type: TeamBriefDto }) team: TeamBriefDto;
  @ApiProperty({ type: 'integer' }) memberCount: number;
  @ApiProperty({ type: 'integer', description: 'Năm lập đội' })
  sinceYear: number;
  @ApiProperty({ type: TeamRecordDto }) record: TeamRecordDto;
  @ApiProperty({ type: 'integer', description: 'Số lượt đánh giá nhận được' })
  reviewCount: number;
  @ApiPropertyOptional({ type: 'number', description: 'Uy tín trung bình 1–5' })
  reputation?: number | null;
  @ApiPropertyOptional({ type: 'number' }) fairplay?: number | null;
  @ApiPropertyOptional({
    type: 'integer',
    description: '% đánh giá có nhãn "Đúng giờ"',
  })
  onTimePercent?: number | null;
  @ApiProperty({ type: [TagCountDto] }) tags: TagCountDto[];
  @ApiProperty({ type: [ReviewItemDto] }) reviews: ReviewItemDto[];
  @ApiProperty({ type: [RecentMatchDto] }) recentMatches: RecentMatchDto[];
}

// ---------- Bảng vàng ----------

export class HonorPlayerDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ type: String }) avatarUrl?: string | null;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
  @ApiProperty({ type: TeamBriefDto }) team: TeamBriefDto;
  @ApiProperty({ type: 'integer' }) goals: number;
  @ApiProperty({ type: 'integer' }) assists: number;
  @ApiProperty({ type: 'integer' }) mvps: number;
}

export class TeamBadgeDto {
  @ApiProperty({ enum: ['unbeaten', 'fairplay'] }) type: string;
  @ApiProperty({
    type: 'number',
    description:
      'unbeaten: số trận bất bại; fairplay: điểm fair-play trung bình',
  })
  value: number;
}

export class HonorsDto {
  @ApiProperty({ example: '2026-11' }) month: string;
  @ApiPropertyOptional({ type: HonorPlayerDto }) playerOfMonth?: HonorPlayerDto;
  @ApiProperty({
    type: [HonorPlayerDto],
    description: 'Vua phá lưới, nhiều bàn nhất trước',
  })
  scorers: HonorPlayerDto[];
  @ApiProperty({
    type: [TeamBadgeDto],
    description: 'Danh hiệu của đội truyền lên (teamId)',
  })
  teamBadges: TeamBadgeDto[];
}

export class HonorsQuery {
  @ApiPropertyOptional({
    example: '2026-11',
    description: 'Tháng YYYY-MM, mặc định tháng này',
  })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}$/)
  month?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Đội cần tính danh hiệu',
  })
  @IsOptional()
  @IsUUID()
  teamId?: string;
}
