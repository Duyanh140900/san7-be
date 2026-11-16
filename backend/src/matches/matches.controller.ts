import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
} from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  CurrentMember,
  TeamRoles,
  TeamScoped,
  type TeamMembership,
} from '../common/team-member.guard.js';
import {
  MatchDetailDto,
  SetResultDto,
  SetStatsDto,
  SubmitReviewDto,
} from './matches.dto.js';
import { MatchesService } from './matches.service.js';

/** Trận của đội: kết quả, thống kê, đánh giá. Thành viên xem; đội trưởng/phó nhập. */
@ApiTags('matches')
@TeamScoped()
@Controller('teams/:teamId/matches')
export class MatchesController {
  constructor(private readonly matches: MatchesService) {}

  @Get(':matchId')
  @ApiOkResponse({ type: MatchDetailDto })
  detail(
    @CurrentMember() me: TeamMembership,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ): Promise<MatchDetailDto> {
    return this.matches.detail(me, matchId);
  }

  @Put(':matchId/result')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: MatchDetailDto })
  setResult(
    @CurrentMember() me: TeamMembership,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: SetResultDto,
  ): Promise<MatchDetailDto> {
    return this.matches.setResult(me, matchId, dto);
  }

  @Post(':matchId/result/confirm')
  @TeamRoles('captain', 'vice')
  @HttpCode(200)
  @ApiOkResponse({ type: MatchDetailDto })
  confirm(
    @CurrentMember() me: TeamMembership,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ): Promise<MatchDetailDto> {
    return this.matches.confirm(me, matchId);
  }

  @Put(':matchId/stats')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: MatchDetailDto })
  setStats(
    @CurrentMember() me: TeamMembership,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: SetStatsDto,
  ): Promise<MatchDetailDto> {
    return this.matches.setStats(me, matchId, dto);
  }

  @Put(':matchId/review')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: MatchDetailDto })
  review(
    @CurrentMember() me: TeamMembership,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: SubmitReviewDto,
  ): Promise<MatchDetailDto> {
    return this.matches.review(me, matchId, dto);
  }
}
