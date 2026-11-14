import { Body, Controller, Get, HttpCode, Post, Query } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import {
  ListNotificationsQuery,
  MarkReadDto,
  NotificationPageDto,
  UnreadCountDto,
} from './notifications.dto.js';
import { NotificationsService } from './notifications.service.js';

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOkResponse({ type: NotificationPageDto })
  list(
    @CurrentUser() user: AuthUser,
    @Query() q: ListNotificationsQuery,
  ): Promise<NotificationPageDto> {
    return this.notifications.list(user.userId, q);
  }

  @Get('unread-count')
  @ApiOkResponse({ type: UnreadCountDto })
  async unreadCount(@CurrentUser() user: AuthUser): Promise<UnreadCountDto> {
    return { count: await this.notifications.unreadCount(user.userId) };
  }

  @Post('read')
  @HttpCode(204)
  @ApiNoContentResponse()
  markRead(
    @CurrentUser() user: AuthUser,
    @Body() dto: MarkReadDto,
  ): Promise<void> {
    return this.notifications.markRead(user.userId, dto.ids);
  }
}
