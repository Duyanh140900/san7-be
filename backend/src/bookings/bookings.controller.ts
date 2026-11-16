import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiCreatedResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import {
  CurrentMember,
  TeamRoles,
  TeamScoped,
  type TeamMembership,
} from '../common/team-member.guard.js';
import {
  BookingDto,
  CreateBookingDto,
  ListBookingsQuery,
  RescheduleBookingDto,
} from './bookings.dto.js';
import { BookingsService } from './bookings.service.js';

/** Đặt sân của đội. Thành viên xem được; đội trưởng/phó mới đặt, đổi, huỷ. */
@ApiTags('bookings')
@TeamScoped()
@Controller('teams/:teamId/bookings')
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Post()
  @TeamRoles('captain', 'vice')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiCreatedResponse({ type: BookingDto })
  hold(
    @CurrentMember() me: TeamMembership,
    @Body() dto: CreateBookingDto,
  ): Promise<BookingDto> {
    return this.bookings.hold(me, dto);
  }

  @Get()
  @ApiOkResponse({ type: [BookingDto] })
  list(
    @CurrentMember() me: TeamMembership,
    @Query() q: ListBookingsQuery,
  ): Promise<BookingDto[]> {
    return this.bookings.list(me, q);
  }

  @Get(':bookingId')
  @ApiOkResponse({ type: BookingDto })
  get(
    @CurrentMember() me: TeamMembership,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ): Promise<BookingDto> {
    return this.bookings.get(me, bookingId);
  }

  @Post(':bookingId/confirm')
  @TeamRoles('captain', 'vice')
  @HttpCode(200)
  @ApiOkResponse({ type: BookingDto })
  confirm(
    @CurrentMember() me: TeamMembership,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ): Promise<BookingDto> {
    return this.bookings.confirm(me, bookingId);
  }

  @Post(':bookingId/cancel')
  @TeamRoles('captain', 'vice')
  @HttpCode(200)
  @ApiOkResponse({ type: BookingDto })
  cancel(
    @CurrentMember() me: TeamMembership,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
  ): Promise<BookingDto> {
    return this.bookings.cancel(me, bookingId);
  }

  @Post(':bookingId/reschedule')
  @TeamRoles('captain', 'vice')
  @HttpCode(200)
  @ApiOkResponse({ type: BookingDto })
  reschedule(
    @CurrentMember() me: TeamMembership,
    @Param('bookingId', ParseUUIDPipe) bookingId: string,
    @Body() dto: RescheduleBookingDto,
  ): Promise<BookingDto> {
    return this.bookings.reschedule(me, bookingId, dto.startAt);
  }
}
