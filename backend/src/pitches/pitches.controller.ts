import { Body, Controller, Get, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  PitchDetailQuery,
  CreatePitchReviewDto,
  FreePitchSlotDto,
  FreePitchSlotsQuery,
  PitchDto,
  PitchListDto,
  PitchListQuery,
  PitchReviewDto,
} from './pitches.dto.js';
import { PitchesService } from './pitches.service.js';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';

/** Tìm sân và khung giờ trống: mọi người đã đăng nhập đều xem được. */
@ApiTags('pitches')
@ApiBearerAuth()
@Controller('pitches')
export class PitchesController {
  constructor(private readonly pitches: PitchesService) {}

  @Get()
  @ApiOkResponse({ type: PitchListDto })
  list(@Query() q: PitchListQuery): Promise<PitchListDto> {
    return this.pitches.list(q);
  }

  @Get('free-slots')
  @ApiOkResponse({ type: [FreePitchSlotDto] })
  freeSlots(@Query() q: FreePitchSlotsQuery): Promise<FreePitchSlotDto[]> {
    return this.pitches.freeSlots(q);
  }

  @Get(':pitchId')
  @ApiOkResponse({ type: PitchDto })
  detail(
    @Param('pitchId', ParseUUIDPipe) pitchId: string,
    @Query() q: PitchDetailQuery,
  ): Promise<PitchDto> {
    return this.pitches.detail(pitchId, q);
  }

  @Get(':pitchId/reviews')
  @ApiOkResponse({ type: [PitchReviewDto] })
  reviews(@Param('pitchId', ParseUUIDPipe) pitchId: string): Promise<PitchReviewDto[]> { return this.pitches.listReviews(pitchId); }

  @Post(':pitchId/reviews')
  @ApiOkResponse({ type: PitchReviewDto })
  createReview(@CurrentUser() user: AuthUser, @Param('pitchId', ParseUUIDPipe) pitchId: string, @Body() dto: CreatePitchReviewDto): Promise<PitchReviewDto> { return this.pitches.createReview(user.userId, pitchId, dto); }
}
