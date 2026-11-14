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
  Put,
  Query,
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import {
  CurrentMember,
  TeamScoped,
  TeamRoles,
  type TeamMembership,
} from '../common/team-member.guard.js';
import {
  AttendanceCountsDto,
  CreateEventDto,
  EventDetailDto,
  EventSummaryDto,
  ListEventsQuery,
  SetAttendanceDto,
  UpdateEventDto,
} from './events.dto.js';
import { EventsService } from './events.service.js';

@ApiTags('events')
@TeamScoped()
@Controller('teams/:teamId/events')
export class EventsController {
  constructor(private readonly events: EventsService) {}

  @Get()
  @ApiOkResponse({ type: [EventSummaryDto] })
  list(
    @CurrentMember() me: TeamMembership,
    @Query() q: ListEventsQuery,
  ): Promise<EventSummaryDto[]> {
    return this.events.list(me, q);
  }

  @Post()
  @TeamRoles('captain', 'vice')
  @ApiCreatedResponse({ type: EventSummaryDto })
  create(
    @CurrentMember() me: TeamMembership,
    @Body() dto: CreateEventDto,
  ): Promise<EventSummaryDto> {
    return this.events.create(me, dto);
  }

  @Get(':eventId')
  @ApiOkResponse({ type: EventDetailDto })
  detail(
    @CurrentMember() me: TeamMembership,
    @Param('eventId', ParseUUIDPipe) eventId: string,
  ): Promise<EventDetailDto> {
    return this.events.detail(me, eventId);
  }

  @Patch(':eventId')
  @TeamRoles('captain', 'vice')
  @ApiOkResponse({ type: EventDetailDto })
  update(
    @CurrentMember() me: TeamMembership,
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Body() dto: UpdateEventDto,
  ): Promise<EventDetailDto> {
    return this.events.update(me, eventId, dto);
  }

  @Delete(':eventId')
  @HttpCode(204)
  @TeamRoles('captain', 'vice')
  @ApiNoContentResponse()
  remove(
    @CurrentMember() me: TeamMembership,
    @Param('eventId', ParseUUIDPipe) eventId: string,
  ): Promise<void> {
    return this.events.remove(me, eventId);
  }

  @Put(':eventId/attendance')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiOkResponse({ type: AttendanceCountsDto })
  setAttendance(
    @CurrentMember() me: TeamMembership,
    @Param('eventId', ParseUUIDPipe) eventId: string,
    @Body() dto: SetAttendanceDto,
  ): Promise<AttendanceCountsDto> {
    return this.events.setAttendance(me, eventId, dto);
  }
}
