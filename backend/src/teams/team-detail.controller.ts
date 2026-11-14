import { Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  CurrentMember,
  TeamScoped,
  TeamRoles,
  type TeamMembership,
} from '../common/team-member.guard.js';
import { InviteDto, TeamDetailDto, UpdateTeamDto } from './teams.dto.js';
import { TeamsService } from './teams.service.js';

@ApiTags('teams')
@TeamScoped()
@Controller('teams/:teamId')
export class TeamDetailController {
  constructor(private readonly teams: TeamsService) {}

  @Get()
  @ApiOkResponse({ type: TeamDetailDto })
  detail(@CurrentMember() me: TeamMembership): Promise<TeamDetailDto> {
    return this.teams.detail(me);
  }

  @Patch()
  @TeamRoles('captain')
  @ApiOkResponse({ type: TeamDetailDto })
  update(
    @CurrentMember() me: TeamMembership,
    @Body() dto: UpdateTeamDto,
  ): Promise<TeamDetailDto> {
    return this.teams.update(me, dto);
  }

  @Post('invite')
  @TeamRoles('captain', 'vice')
  @ApiCreatedResponse({ type: InviteDto })
  regenerateInvite(@CurrentMember() me: TeamMembership): Promise<InviteDto> {
    return this.teams.regenerateInvite(me);
  }
}
