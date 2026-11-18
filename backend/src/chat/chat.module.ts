import { Module } from '@nestjs/common';
import { ChatController, ChatReadController, InboxController } from './chat.controller.js';
import { ChatService } from './chat.service.js';

@Module({
  controllers: [ChatController, ChatReadController, InboxController],
  providers: [ChatService],
})
export class ChatModule {}
