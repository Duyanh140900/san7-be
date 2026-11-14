import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import {
  CurrentMember,
  TeamScoped,
  TeamRoles,
  type TeamMembership,
} from '../common/team-member.guard.js';
import { ChangeRoleDto, MemberListDto } from './members.dto.js';
import { MembersService } from './members.service.js';

@ApiTags('members')
@TeamScoped()
@Controller('teams/:teamId/members')
export class MembersController {
  constructor(private readonly members: MembersService) {}

  @Get()
  @ApiOkResponse({ type: MemberListDto })
  list(@CurrentMember() me: TeamMembership): Promise<MemberListDto> {
    return this.members.list(me);
  }

  @Delete('me')
  @HttpCode(204)
  @ApiNoContentResponse({ description: 'Rời đội' })
  leave(@CurrentMember() me: TeamMembership): Promise<void> {
    return this.members.leave(me);
  }

  @Post(':userId/approve')
  @HttpCode(204)
  @TeamRoles('captain', 'vice')
  @ApiNoContentResponse()
  approve(
    @CurrentMember() me: TeamMembership,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<void> {
    return this.members.approve(me, userId);
  }

  @Post(':userId/reject')
  @HttpCode(204)
  @TeamRoles('captain', 'vice')
  @ApiNoContentResponse()
  reject(
    @CurrentMember() me: TeamMembership,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<void> {
    return this.members.reject(me, userId);
  }

  @Patch(':userId')
  @HttpCode(204)
  @TeamRoles('captain')
  @ApiNoContentResponse()
  changeRole(
    @CurrentMember() me: TeamMembership,
    @Param('userId', ParseUUIDPipe) userId: string,
    @Body() dto: ChangeRoleDto,
  ): Promise<void> {
    return this.members.changeRole(me, userId, dto.role);
  }

  @Delete(':userId')
  @HttpCode(204)
  @TeamRoles('captain')
  @ApiNoContentResponse()
  remove(
    @CurrentMember() me: TeamMembership,
    @Param('userId', ParseUUIDPipe) userId: string,
  ): Promise<void> {
    return this.members.remove(me, userId);
  }
}
