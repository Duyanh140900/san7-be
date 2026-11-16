import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiCreatedResponse, ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentMember, TeamRoles, TeamScoped, type TeamMembership } from '../common/team-member.guard.js';
import { CreatePostScheduleDto, PostScheduleDto, UpdatePostScheduleDto } from './schedules.dto.js';
import { PostSchedulesService } from './schedules.service.js';

@ApiTags('post-schedules')
@TeamScoped()
@Controller('teams/:teamId/post-schedules')
export class PostSchedulesController {
  constructor(private readonly schedules: PostSchedulesService) {}
  @Post() @TeamRoles('captain', 'vice') @ApiCreatedResponse({ type: PostScheduleDto })
  create(@CurrentMember() me: TeamMembership, @Body() dto: CreatePostScheduleDto) { return this.schedules.create(me, dto); }
  @Patch(':scheduleId') @TeamRoles('captain', 'vice') @ApiOkResponse({ type: PostScheduleDto })
  update(@CurrentMember() me: TeamMembership, @Param('scheduleId', ParseUUIDPipe) id: string, @Body() dto: UpdatePostScheduleDto) { return this.schedules.update(me, id, dto); }
  @Delete(':scheduleId') @TeamRoles('captain', 'vice') @HttpCode(204) @ApiNoContentResponse()
  cancel(@CurrentMember() me: TeamMembership, @Param('scheduleId', ParseUUIDPipe) id: string) { return this.schedules.cancel(me, id); }
}
