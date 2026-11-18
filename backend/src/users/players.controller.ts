import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { PublicPlayerDto } from './users.dto.js';
import { UsersService } from './users.service.js';

@ApiTags('players')
@Controller('players')
export class PlayersController {
  constructor(private readonly users: UsersService) {}
  @Get(':id') @ApiOkResponse({ type: PublicPlayerDto })
  get(@Param('id', ParseUUIDPipe) id: string): Promise<PublicPlayerDto> { return this.users.publicPlayer(id); }
}
