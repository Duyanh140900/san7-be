import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayUnique,
  IsArray,
  IsDate,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MAX_AMOUNT } from '../common/money.js';
import { Trim } from '../common/trim.js';
import {
  Position,
  ApplicationStatus,
  PostDeal,
  PostStatus,
  PostType,
  RequestStatus,
  TeamLevel,
} from '../generated/prisma/enums.js';

// ---------- Đầu vào ----------

export class CreatePostDto {
  @ApiProperty({ enum: PostType, enumName: 'PostType' })
  @IsEnum(PostType)
  type: PostType;

  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  startAt: Date;

  @ApiProperty({ type: String, format: 'date-time' })
  @Type(() => Date)
  @IsDate()
  endAt: Date;

  @ApiPropertyOptional({ maxLength: 120, example: 'Sân bóng Phúc La' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(120)
  pitchName?: string;

  @ApiPropertyOptional({
    maxLength: 50,
    description: 'Vắng = khu vực của đội',
  })
  @IsOptional()
  @Trim()
  @IsString()
  @Length(1, 50)
  area?: string;

  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' })
  @IsEnum(TeamLevel)
  level: TeamLevel;

  @ApiPropertyOptional({
    enum: PostDeal,
    enumName: 'PostDeal',
    description: 'Bắt buộc với kèo tìm đối',
  })
  @IsOptional()
  @IsEnum(PostDeal)
  deal?: PostDeal;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 0,
    maximum: 100,
    description: 'Phần trăm đội thắng trả (chỉ khi chia tiền sân)',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  ratioWin?: number;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  ratioLose?: number;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 0,
    maximum: MAX_AMOUNT,
    description: 'Tiền sân (VND); với pass sân là giá nhượng',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(MAX_AMOUNT)
  pitchPrice?: number;

  @ApiPropertyOptional({
    enum: Position,
    enumName: 'Position',
    isArray: true,
    description: 'Tuyển người: các vị trí cần',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @IsEnum(Position, { each: true })
  positions?: Position[];

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 20 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  playersNeeded?: number;

  @ApiPropertyOptional({ maxLength: 1000 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(1000)
  body?: string;

  @ApiPropertyOptional({
    format: 'uuid',
    description:
      'Đăng kèo cho sân đã đặt: giờ và sân lấy theo lượt đặt, bỏ qua startAt/endAt/pitchName',
  })
  @IsOptional()
  @IsUUID()
  bookingId?: string;

  @ApiPropertyOptional({
    type: [String],
    maxItems: 4,
    description: 'Khóa ảnh đã tải lên bằng API media, theo thứ tự hiển thị',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(512, { each: true })
  mediaKeys?: string[];
}

export class FeedQuery {
  @ApiPropertyOptional({ enum: PostType, enumName: 'PostType' })
  @IsOptional()
  @IsEnum(PostType)
  type?: PostType;

  @ApiPropertyOptional({ maxLength: 50, example: 'Cầu Giấy' })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(50)
  area?: string;

  @ApiPropertyOptional({
    description: 'Cursor phân trang của bảng tin',
    maxLength: 255,
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  cursor?: string;

  @ApiPropertyOptional({
    maxLength: 100,
    description: 'Tìm theo tên đội, khu vực hoặc tên sân',
  })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(100)
  q?: string;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 1,
    maximum: 30,
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  limit?: number;
}

export class MyPostsQuery {
  @ApiPropertyOptional({ enum: PostStatus, enumName: 'PostStatus' })
  @IsOptional()
  @IsEnum(PostStatus)
  status?: PostStatus;

  @ApiPropertyOptional({ format: 'uuid' })
  @IsOptional()
  @IsUUID()
  cursor?: string;

  @ApiPropertyOptional({ type: 'integer', minimum: 1, maximum: 30, default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(30)
  limit?: number;
}

export class SendRequestDto {
  @ApiProperty({ type: 'integer', minimum: 1, maximum: 30, example: 9 })
  @IsInt()
  @Min(1)
  @Max(30)
  peopleCount: number;

  @ApiPropertyOptional({
    type: 'integer',
    minimum: 0,
    maximum: 100,
    description: 'Tỷ lệ đề xuất khác; vắng = đồng ý tỷ lệ của kèo',
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  ratioWin?: number;

  @ApiPropertyOptional({ type: 'integer', minimum: 0, maximum: 100 })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  ratioLose?: number;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(300)
  message?: string;
}

export class CreatePostApplicationDto {
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  @IsOptional()
  @IsEnum(Position)
  position?: Position;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @Trim()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class UpdatePostApplicationDto {
  @ApiProperty({ enum: ['accepted', 'rejected'] })
  @IsEnum(['accepted', 'rejected'])
  status: 'accepted' | 'rejected';
}

// ---------- Đầu ra ----------

export class TeamBriefDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty({ example: '#0066CC' }) crestColor: string;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
}

export class PostMediaDto {
  @ApiProperty({ example: 'users/<user-id>/post/<image-id>.jpg' }) key: string;
  @ApiProperty({ format: 'uri' }) url: string;
}

export class PostDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: PostType, enumName: 'PostType' }) type: PostType;
  @ApiProperty({ type: TeamBriefDto }) team: TeamBriefDto;
  @ApiProperty({ type: String, format: 'date-time' }) startAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) endAt: Date;
  @ApiPropertyOptional({ type: String }) pitchName?: string | null;
  @ApiProperty() area: string;
  @ApiProperty({ enum: TeamLevel, enumName: 'TeamLevel' }) level: TeamLevel;
  @ApiPropertyOptional({ enum: PostDeal, enumName: 'PostDeal' })
  deal?: PostDeal | null;
  @ApiPropertyOptional({ type: 'integer' }) ratioWin?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) ratioLose?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) pitchPrice?: number | null;
  @ApiProperty({ enum: Position, enumName: 'Position', isArray: true })
  positions: Position[];
  @ApiPropertyOptional({ type: 'integer' }) playersNeeded?: number | null;
  @ApiPropertyOptional({ type: String }) body?: string | null;
  @ApiProperty({ type: [PostMediaDto] }) media: PostMediaDto[];
  @ApiProperty({ enum: PostStatus, enumName: 'PostStatus' })
  status: PostStatus;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
  @ApiProperty({
    type: 'integer',
    description: 'Số yêu cầu nhận kèo đang chờ',
  })
  requestCount: number;
  @ApiPropertyOptional({
    enum: ApplicationStatus,
    enumName: 'ApplicationStatus',
    description: 'Trạng thái ứng tuyển của tôi cho kèo tuyển người',
  })
  myApplicationStatus?: ApplicationStatus;
}

export class FeedPageDto {
  @ApiProperty({
    type: 'array',
    items: {
      oneOf: [
        { $ref: '#/components/schemas/PostDto' },
        { $ref: '#/components/schemas/FeedMatchResultItemDto' },
      ],
    },
  })
  items: FeedItemDto[];
  @ApiPropertyOptional({
    type: String,
    description: 'Truyền lại để lấy trang sau',
  })
  nextCursor?: string;
}

export class ResultTeamDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
  @ApiProperty({ example: '#0066CC' }) crestColor: string;
  @ApiProperty({ type: 'integer' }) score: number;
}

export class MatchScorerDto {
  @ApiProperty() name: string;
  @ApiProperty({ type: 'integer' }) goals: number;
}

export class FeedMatchResultDto {
  @ApiProperty({ format: 'uuid' }) matchId: string;
  @ApiProperty({ type: String, format: 'date-time' }) playedAt: Date;
  @ApiProperty({ type: ResultTeamDto }) teamA: ResultTeamDto;
  @ApiProperty({ type: ResultTeamDto }) teamB: ResultTeamDto;
  @ApiProperty({ type: [MatchScorerDto] }) scorers: MatchScorerDto[];
  @ApiPropertyOptional({ type: String }) mvpName?: string | null;
}

export class FeedMatchResultItemDto {
  @ApiProperty({ enum: ['match_result'] }) kind: 'match_result';
  @ApiProperty({ type: FeedMatchResultDto }) result: FeedMatchResultDto;
}

export type FeedItemDto = PostDto | FeedMatchResultItemDto;

export class MyRequestDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) teamId: string;
  @ApiProperty() teamName: string;
  @ApiProperty({ enum: RequestStatus, enumName: 'RequestStatus' })
  status: RequestStatus;
  @ApiProperty({ type: String, format: 'date-time' }) expiresAt: Date;
}

export class PostDetailDto {
  @ApiProperty({ type: PostDto }) post: PostDto;
  @ApiProperty({
    description: 'Tôi là đội trưởng/phó của đội đăng kèo',
  })
  canManage: boolean;
  @ApiPropertyOptional({
    type: MyRequestDto,
    description: 'Yêu cầu gần nhất của một đội tôi quản lý cho kèo này',
  })
  myRequest?: MyRequestDto;
  @ApiPropertyOptional({ enum: ApplicationStatus, enumName: 'ApplicationStatus' })
  myApplicationStatus?: ApplicationStatus;
  @ApiProperty({
    type: [TeamBriefDto],
    description: 'Các đội đang chờ (tối đa 5, để hiện avatar)',
  })
  requestTeams: TeamBriefDto[];
  @ApiPropertyOptional({ type: Number, format: 'double' }) venueLat?: number | null;
  @ApiPropertyOptional({ type: Number, format: 'double' }) venueLng?: number | null;
  @ApiProperty({ type: () => [PostLineupPlayerDto] }) lineup: PostLineupPlayerDto[];
}

export class PostLineupPlayerDto {
  @ApiProperty({ format: 'uuid' }) userId: string;
  @ApiProperty() name: string;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
}

export class PostApplicationUserDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() name: string;
}

export class PostApplicationDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ enum: ApplicationStatus, enumName: 'ApplicationStatus' })
  status: ApplicationStatus;
  @ApiProperty({ type: PostApplicationUserDto }) user: PostApplicationUserDto;
  @ApiPropertyOptional({ enum: Position, enumName: 'Position' })
  position?: Position | null;
  @ApiPropertyOptional({ type: String }) note?: string | null;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
}

export class RequestTeamDto extends TeamBriefDto {
  @ApiProperty({ type: 'integer' }) memberCount: number;
  @ApiProperty({ type: 'integer', description: 'Số trận đã đá trên Sân 7' })
  matchesPlayed: number;
  @ApiProperty({
    type: 'integer',
    description: 'Số lần đã gặp đội đăng kèo',
  })
  headToHead: number;
  @ApiProperty({
    type: 'integer',
    description: 'Trong các lần gặp: số lần đội đăng kèo thắng',
  })
  h2hOwnerWins: number;
  @ApiProperty({
    type: 'integer',
    description: 'Trong các lần gặp: số lần đội đăng kèo thua',
  })
  h2hOwnerLosses: number;
  @ApiProperty({ type: 'integer', description: 'Số lượt đánh giá nhận được' })
  reviewCount: number;
  @ApiPropertyOptional({ type: 'number', description: 'Uy tín trung bình 1–5' })
  reputation?: number | null;
  @ApiPropertyOptional({
    type: 'integer',
    description: '% đánh giá có nhãn "Đúng giờ"',
  })
  onTimePercent?: number | null;
}

export class MatchRequestDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty({ format: 'uuid' }) postId: string;
  @ApiProperty({
    enum: RequestStatus,
    enumName: 'RequestStatus',
    description: 'Đã tính hết hạn theo giờ hiện tại',
  })
  status: RequestStatus;
  @ApiProperty({ type: String, format: 'date-time' }) expiresAt: Date;
  @ApiProperty({ type: String, format: 'date-time' }) createdAt: Date;
  @ApiProperty({ type: 'integer' }) peopleCount: number;
  @ApiPropertyOptional({ type: 'integer' }) ratioWin?: number | null;
  @ApiPropertyOptional({ type: 'integer' }) ratioLose?: number | null;
  @ApiPropertyOptional({ type: String }) message?: string | null;
  @ApiProperty({ type: RequestTeamDto }) team: RequestTeamDto;
  @ApiPropertyOptional({
    type: Number,
    description:
      'Khoảng cách từ vị trí sân nhà/khu vực đã có toạ độ của đội nhận kèo tới sân của kèo (km)',
  })
  distanceKm?: number | null;
}

export class RequestDetailDto {
  @ApiProperty({ type: MatchRequestDto }) request: MatchRequestDto;
  @ApiProperty({ type: PostDto }) post: PostDto;
  @ApiProperty({
    enum: ['owner', 'requester'],
    description: 'Tôi xem với tư cách đội đăng kèo hay đội gửi yêu cầu',
  })
  side: 'owner' | 'requester';
  @ApiProperty({
    description: 'Được chấp nhận/từ chối (owner) hoặc huỷ (requester)',
  })
  canRespond: boolean;
  @ApiProperty({
    type: [TeamBriefDto],
    description: 'Các đội khác đang chờ cùng kèo (chỉ owner thấy)',
  })
  otherPending: TeamBriefDto[];
  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Lịch đội của tôi sau khi chốt',
  })
  eventId?: string;
}

export class AcceptResultDto {
  @ApiPropertyOptional({ format: 'uuid' }) matchId?: string;
  @ApiPropertyOptional({
    format: 'uuid',
    description: 'Lịch trận trong đội của tôi (vắng với pass sân)',
  })
  eventId?: string;
}
