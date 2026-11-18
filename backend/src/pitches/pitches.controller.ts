import { Controller, Get, Param, ParseUUIDPipe, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  PitchDetailQuery,
  FreePitchSlotDto,
  FreePitchSlotsQuery,
  PitchDto,
  PitchListDto,
  PitchListQuery,
} from './pitches.dto.js';
import { PitchesService } from './pitches.service.js';

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
}
