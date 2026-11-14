import { InjectQueue, Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job, Queue } from 'bullmq';
import { expireRequest } from '../posts/requests.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { PushService } from './push.service.js';

export { SYSTEM_QUEUE };

/** Hàng đợi hệ thống: hết hạn yêu cầu nhận kèo, gửi push. */
@Processor(SYSTEM_QUEUE)
export class SystemProcessor extends WorkerHost {
  private readonly logger = new Logger(SystemProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    @InjectQueue(SYSTEM_QUEUE) private readonly queue: Queue,
  ) {
    super();
  }

  async process(job: Job): Promise<unknown> {
    switch (job.name) {
      case Jobs.ping:
        this.logger.log(`ping ${job.id}`);
        return { pong: true };
      case Jobs.requestExpire: {
        const { requestId } = job.data as { requestId: string };
        const notes = await expireRequest(this.prisma, requestId, new Date());
        if (notes.length) {
          await this.queue.add(
            Jobs.pushSend,
            { notificationIds: notes.map((n) => n.id) },
            { attempts: 3, removeOnComplete: true, removeOnFail: 100 },
          );
        }
        return { expired: notes.length > 0 };
      }
      case Jobs.pushSend: {
        const { notificationIds } = job.data as { notificationIds: string[] };
        return { sent: await this.push.sendNotifications(notificationIds) };
      }
      default:
        throw new Error(`Job không xác định: ${job.name}`);
    }
  }
}
