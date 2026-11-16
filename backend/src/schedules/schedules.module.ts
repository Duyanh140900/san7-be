import { Module } from '@nestjs/common';
import { QueueModule } from '../queue/queue.module.js';
import { PostSchedulesController } from './schedules.controller.js';
import { PostSchedulesService } from './schedules.service.js';
@Module({ imports: [QueueModule], controllers: [PostSchedulesController], providers: [PostSchedulesService] })
export class PostSchedulesModule {}
