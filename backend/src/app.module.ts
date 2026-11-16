import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';
import { AttendanceModule } from './attendance/attendance.module.js';
import { AuthModule } from './auth/auth.module.js';
import { ChatModule } from './chat/chat.module.js';
import { CommunityModule } from './community/community.module.js';
import { validateEnv } from './common/env.js';
import { FundsModule } from './funds/funds.module.js';
import { HealthController } from './health/health.controller.js';
import { MatchesModule } from './matches/matches.module.js';
import { MediaModule } from './media/media.module.js';
import { MembersModule } from './members/members.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { PitchesModule } from './pitches/pitches.module.js';
import { PostsModule } from './posts/posts.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { QueueModule } from './queue/queue.module.js';
import { RealtimeModule } from './realtime/realtime.module.js';
import { TeamsModule } from './teams/teams.module.js';
import { UsersModule } from './users/users.module.js';
import { PostSchedulesModule } from './schedules/schedules.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      // Chạy ngoài Docker: đọc .env ở gốc repo
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
        redact: [
          'req.headers.authorization',
          'req.body.idToken',
          'req.body.refreshToken',
        ],
        autoLogging: { ignore: (req) => req.url === '/v1/health' },
      },
    }),
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 120 }]),
    PrismaModule,
    QueueModule,
    AuthModule,
    CommunityModule,
    ChatModule,
    MediaModule,
    UsersModule,
    TeamsModule,
    MembersModule,
    AttendanceModule,
    FundsModule,
    RealtimeModule,
    NotificationsModule,
    PostsModule,
    PostSchedulesModule,
    PitchesModule,
    MatchesModule,
  ],
  controllers: [HealthController],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
