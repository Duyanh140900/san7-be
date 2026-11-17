import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { PostsController, TeamPostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';
import { RequestsService } from './requests.service.js';

@Module({
  imports: [MediaModule],
  controllers: [PostsController, TeamPostsController],
  providers: [PostsService, RequestsService],
})
export class PostsModule {}
