import { Module } from '@nestjs/common';
import { PostsController, TeamPostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';
import { RequestsService } from './requests.service.js';

@Module({
  controllers: [PostsController, TeamPostsController],
  providers: [PostsService, RequestsService],
})
export class PostsModule {}
