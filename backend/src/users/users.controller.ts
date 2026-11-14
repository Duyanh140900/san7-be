import { Body, Controller, Get, HttpCode, Patch, Post } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import { MeDto, RegisterDeviceDto, UpdateMeDto } from './users.dto.js';
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

  @Post('devices')
  @HttpCode(204)
  @ApiNoContentResponse()
  registerDevice(
    @CurrentUser() user: AuthUser,
    @Body() dto: RegisterDeviceDto,
  ): Promise<void> {
    return this.users.registerDevice(user.userId, dto);
  }
}
