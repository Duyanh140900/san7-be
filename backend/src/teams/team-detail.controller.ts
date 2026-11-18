import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  CurrentMember,
  TeamScoped,
  TeamRoles,
  type TeamMembership,
} from '../common/team-member.guard.js';
import { InviteDto, MembershipDto, TeamDetailDto, TeamMemberDto, UpdateMemberRoleDto, UpdateTeamDto } from './teams.dto.js';
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

  @Get('join-requests')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: [TeamMemberDto] })
  joinRequests(@CurrentMember() me: TeamMembership): Promise<TeamMemberDto[]> {
    return this.teams.joinRequests(me);
  }

  @Post('join-requests/:userId/approve')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: MembershipDto })
  approveJoin(@CurrentMember() me: TeamMembership, @Param('userId', ParseUUIDPipe) userId: string): Promise<MembershipDto> {
    return this.teams.resolveJoinRequest(me, userId, true);
  }

  @Post('join-requests/:userId/reject')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: MembershipDto })
  rejectJoin(@CurrentMember() me: TeamMembership, @Param('userId', ParseUUIDPipe) userId: string): Promise<MembershipDto> {
    return this.teams.resolveJoinRequest(me, userId, false);
  }

  @Patch('members/:userId/role')
  @TeamRoles('captain')
  @ApiOkResponse({ type: TeamMemberDto })
  updateMemberRole(@CurrentMember() me: TeamMembership, @Param('userId', ParseUUIDPipe) userId: string, @Body() dto: UpdateMemberRoleDto): Promise<TeamMemberDto> {
    return this.teams.updateMemberRole(me, userId, dto.role);
  }
}
