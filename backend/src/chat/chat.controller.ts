import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import {
  CursorPageQuery,
  MessageDto,
  MessagePageDto,
  ChatReadDto,
  InboxDto,
  SendMessageDto,
} from './chat.dto.js';
import { ChatService } from './chat.service.js';

/** Chat hai đội trong một trận. Chỉ thành viên active của hai đội được đọc/gửi (403 chat_forbidden). */
@ApiTags('chat')
@ApiBearerAuth()
@Controller('matches/:matchId/messages')
export class ChatController {
  constructor(private readonly chat: ChatService) {}

  @Post()
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiCreatedResponse({ type: MessageDto })
  send(
    @CurrentUser() user: AuthUser,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Body() dto: SendMessageDto,
  ): Promise<MessageDto> {
    return this.chat.send(user.userId, matchId, dto);
  }

  @Get()
  @ApiOkResponse({ type: MessagePageDto })
  list(
    @CurrentUser() user: AuthUser,
    @Param('matchId', ParseUUIDPipe) matchId: string,
    @Query() q: CursorPageQuery,
  ): Promise<MessagePageDto> {
    return this.chat.list(user.userId, matchId, q);
  }

}

@ApiTags('chat')
@ApiBearerAuth()
@Controller('matches/:matchId/chat')
export class ChatReadController {
  constructor(private readonly chat: ChatService) {}

  @Post('read')
  @ApiOkResponse({ type: ChatReadDto })
  read(
    @CurrentUser() user: AuthUser,
    @Param('matchId', ParseUUIDPipe) matchId: string,
  ): Promise<ChatReadDto> {
    return this.chat.read(user.userId, matchId);
  }
}

@ApiTags('chat')
@ApiBearerAuth()
@Controller('inbox')
export class InboxController {
  constructor(private readonly chat: ChatService) {}
  @Get()
  @ApiOkResponse({ type: InboxDto })
  list(@CurrentUser() user: AuthUser): Promise<InboxDto> { return this.chat.inbox(user.userId); }
}
