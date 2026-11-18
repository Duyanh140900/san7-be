import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import {
  CreateTeamDto,
  JoinTeamDto,
  MembershipDto,
  TeamDto,
  TeamInvitePreviewDto,
  TeamPublicProfileDto,
} from './teams.dto.js';
import { TeamsService } from './teams.service.js';

@ApiTags('teams')
@ApiBearerAuth()
@Controller('teams')
export class TeamsController {
  constructor(private readonly teams: TeamsService) {}

  @Post()
  @ApiCreatedResponse({ type: TeamDto })
  create(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateTeamDto,
  ): Promise<TeamDto> {
    return this.teams.create(user.userId, dto);
  }

  @Get('invites/:code')
  @ApiOkResponse({ type: TeamInvitePreviewDto })
  previewInvite(@Param('code') code: string): Promise<TeamInvitePreviewDto> {
    return this.teams.previewInvite(code);
  }

  @Post('join')
  @ApiCreatedResponse({ type: MembershipDto })
  join(
    @CurrentUser() user: AuthUser,
    @Body() dto: JoinTeamDto,
  ): Promise<MembershipDto> {
    return this.teams.join(user.userId, dto.code);
  }

  @Get(':teamId/profile')
  @ApiOkResponse({ type: TeamPublicProfileDto })
  profile(@CurrentUser() user: AuthUser, @Param('teamId', ParseUUIDPipe) teamId: string): Promise<TeamPublicProfileDto> { return this.teams.publicProfile(user.userId, teamId); }

  @Post(':teamId/follow')
  @HttpCode(204)
  async follow(@CurrentUser() user: AuthUser, @Param('teamId', ParseUUIDPipe) teamId: string): Promise<void> { await this.teams.follow(user.userId, teamId); }

  @Delete(':teamId/follow')
  @HttpCode(204)
  async unfollow(@CurrentUser() user: AuthUser, @Param('teamId', ParseUUIDPipe) teamId: string): Promise<void> { await this.teams.unfollow(user.userId, teamId); }
}
