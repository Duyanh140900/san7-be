import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { Redis } from 'ioredis';
import { LoggerModule } from 'nestjs-pino';
import { validateEnv, type Env } from '../common/env.js';
import { PrismaModule } from '../prisma/prisma.module.js';
import { SystemProcessor, SYSTEM_QUEUE } from './system.processor.js';

/** Module của tiến trình worker: chỉ chạy processor BullMQ, không mở HTTP. */
@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['../.env', '.env'],
      validate: validateEnv,
    }),
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL ?? 'info',
        transport:
          process.env.NODE_ENV === 'production'
            ? undefined
            : { target: 'pino-pretty' },
      },
    }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      // BullMQ bản ESM cần truyền sẵn client ioredis (không tự nạp từ connection options)
      useFactory: (config: ConfigService<Env, true>) => ({
        connection: new Redis(config.get('REDIS_URL'), {
          maxRetriesPerRequest: null,
        }),
        prefix: 'san7',
      }),
    }),
    BullModule.registerQueue({ name: SYSTEM_QUEUE }),
    PrismaModule,
  ],
  providers: [SystemProcessor],
})
export class JobsModule {}
