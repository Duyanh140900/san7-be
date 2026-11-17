import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { PostsController, TeamPostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';
import { RequestsService } from './requests.service.js';
import { ApplicationsService } from './applications.service.js';

@Module({
  imports: [MediaModule],
  controllers: [PostsController, TeamPostsController],
  providers: [PostsService, RequestsService, ApplicationsService],
})
export class PostsModule {}
