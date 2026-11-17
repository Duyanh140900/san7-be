import { Body, Controller, Delete, Get, HttpCode, Patch, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import { MeDto, NotificationSettingsDto, RegisterDeviceDto, UpdateMeDto, UpdateNotificationSettingsDto } from './users.dto.js';
import { UsersService } from './users.service.js';

@ApiTags('users')
@ApiBearerAuth()
@Controller('me')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get()
  @ApiOkResponse({ type: MeDto })
  getMe(@CurrentUser() user: AuthUser): Promise<MeDto> {
    return this.users.getMe(user.userId);
  }

  @Patch()
  @ApiOkResponse({ type: MeDto })
  updateMe(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpdateMeDto,
  ): Promise<MeDto> {
    return this.users.updateMe(user.userId, dto);
  }

  @Get('notification-settings')
  @ApiOkResponse({ type: NotificationSettingsDto })
  getNotificationSettings(@CurrentUser() user: AuthUser): Promise<NotificationSettingsDto> {
    return this.users.getNotificationSettings(user.userId);
  }

  @Patch('notification-settings')
  @ApiOkResponse({ type: NotificationSettingsDto })
  updateNotificationSettings(@CurrentUser() user: AuthUser, @Body() dto: UpdateNotificationSettingsDto): Promise<NotificationSettingsDto> {
    return this.users.updateNotificationSettings(user.userId, dto);
  }

  @Post('devices')
  @HttpCode(204)
  @ApiNoContentResponse()
  registerDevice(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<void> {
    return this.users.registerDevice(user.userId, dto);
  }

  @Delete()
  @HttpCode(204)
  @ApiNoContentResponse()
  removeAccount(@CurrentUser() user: AuthUser): Promise<void> {
    return this.users.removeAccount(user.userId);
  }
}
