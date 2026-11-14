import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import type { Env } from '../common/env.js';

/** Prisma client dùng chung. Kết nối lười: chỉ mở khi có truy vấn đầu tiên. */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor(config: ConfigService<Env, true>) {
    super({
      adapter: new PrismaPg({ connectionString: config.get('DATABASE_URL') }),
    });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
