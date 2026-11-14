import { NestFactory } from '@nestjs/core';
import { Logger } from 'nestjs-pino';
import { JobsModule } from './jobs/jobs.module.js';

const app = await NestFactory.createApplicationContext(JobsModule, {
  bufferLogs: true,
});
app.useLogger(app.get(Logger));
app.enableShutdownHooks();
app.get(Logger).log('Worker đã sẵn sàng');
