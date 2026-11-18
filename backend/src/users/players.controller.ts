import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { CurrentUser, OptionalAuth, type AuthUser } from '../common/auth.decorators.js';
import { PublicPlayerDto } from './users.dto.js';
import { UsersService } from './users.service.js';

@ApiTags('players')
@Controller('players')
export class PlayersController {
  constructor(private readonly users: UsersService) {}
  @Get(':id') @OptionalAuth() @ApiOkResponse({ type: PublicPlayerDto })
  get(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() viewer?: AuthUser): Promise<PublicPlayerDto> { return this.users.publicPlayer(id, viewer?.userId); }
}
