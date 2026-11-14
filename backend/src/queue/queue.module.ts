import { BullModule, InjectQueue } from '@nestjs/bullmq';
import { Global, Module, type OnApplicationShutdown } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Queue } from 'bullmq';
import { Redis } from 'ioredis';
import type { Env } from '../common/env.js';
import { SYSTEM_QUEUE } from './queue.constants.js';

/** Kết nối BullMQ dùng chung cho api và worker. */
@Global()
@Module({
  imports: [
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
  ],
  exports: [BullModule],
})
export class QueueModule implements OnApplicationShutdown {
  constructor(@InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue) {}

  /** Kết nối truyền từ ngoài vào BullMQ không tự đóng: đóng khi tắt để tiến trình thoát gọn. */
  async onApplicationShutdown() {
    await this.queue.disconnect();
  }
}
