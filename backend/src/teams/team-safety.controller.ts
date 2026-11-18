import { Body, Controller, Delete, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentMember, TeamScoped, type TeamMembership } from '../common/team-member.guard.js';
import { CreateTeamReportDto, TeamSafetyDto } from './team-safety.dto.js';
import { TeamsService } from './teams.service.js';
@ApiTags('teams')
@TeamScoped()
@Controller('teams/:teamId')
export class TeamSafetyController {
  constructor(private readonly teams: TeamsService) {}
  @Post('reports') @ApiCreatedResponse({ type: TeamSafetyDto })
  report(@CurrentMember() me: TeamMembership, @Body() dto: CreateTeamReportDto): Promise<TeamSafetyDto> { return this.teams.report(me, dto); }
  @Post('blocks/:blockedTeamId') @ApiOkResponse({ type: TeamSafetyDto })
  block(@CurrentMember() me: TeamMembership, @Param('blockedTeamId', ParseUUIDPipe) blockedTeamId: string): Promise<TeamSafetyDto> { return this.teams.block(me, blockedTeamId); }
  @Delete('blocks/:blockedTeamId') @HttpCode(204)
  async unblock(@CurrentMember() me: TeamMembership, @Param('blockedTeamId', ParseUUIDPipe) blockedTeamId: string): Promise<void> { await this.teams.unblock(me, blockedTeamId); }
}
