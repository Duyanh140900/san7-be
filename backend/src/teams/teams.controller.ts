import { Body, Controller, Get, Param, Post } from '@nestjs/common';
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
}
