import { Module } from '@nestjs/common';
import { ChatController, ChatReadController } from './chat.controller.js';
import { ChatService } from './chat.service.js';

@Module({
  controllers: [ChatController, ChatReadController],
  providers: [ChatService],
})
export class ChatModule {}
