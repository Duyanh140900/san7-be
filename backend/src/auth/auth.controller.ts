import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { ApiNoContentResponse, ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Public } from '../common/auth.decorators.js';
import {
  AuthResponseDto,
  GoogleLoginDto,
  RefreshDto,
  TokenPairDto,
} from './auth.dto.js';
import { AuthService } from './auth.service.js';

@ApiTags('auth')
@Public()
@Throttle({ default: { limit: 10, ttl: 60_000 } })
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('google')
  @HttpCode(200)
  @ApiOkResponse({ type: AuthResponseDto })
  google(@Body() dto: GoogleLoginDto): Promise<AuthResponseDto> {
    return this.auth.loginWithGoogle(dto.idToken);
  }

  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({ type: TokenPairDto })
  refresh(@Body() dto: RefreshDto): Promise<TokenPairDto> {
    return this.auth.refresh(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  @ApiNoContentResponse()
  logout(@Body() dto: RefreshDto): Promise<void> {
    return this.auth.logout(dto.refreshToken);
  }
}
