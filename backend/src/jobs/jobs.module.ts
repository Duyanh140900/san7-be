import { BullModule } from '@nestjs/bullmq';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
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
      useFactory: (config: ConfigService<Env, true>) => ({
        connection: { url: config.get('REDIS_URL') },
        prefix: 'san7',
      }),
    }),
    BullModule.registerQueue({ name: SYSTEM_QUEUE }),
    PrismaModule,
  ],
  providers: [SystemProcessor],
})
export class JobsModule {}
