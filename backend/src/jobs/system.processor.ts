import { InjectQueue, Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job, Queue } from 'bullmq';
import { expireHold } from '../bookings/bookings.service.js';
import { promptMatchResult } from '../matches/match-prompt.js';
import { expireRequest } from '../posts/requests.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { PushService } from './push.service.js';
import { postScheduleJobId, publishPostSchedule } from '../schedules/schedules.service.js';
import { MediaService } from '../media/media.service.js';

export { SYSTEM_QUEUE };

/** Hàng đợi hệ thống: hết hạn yêu cầu nhận kèo, gửi push. */
@Processor(SYSTEM_QUEUE)
export class SystemProcessor extends WorkerHost {
  private readonly logger = new Logger(SystemProcessor.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    private readonly media: MediaService,
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
      case Jobs.bookingExpire: {
        const { bookingId } = job.data as { bookingId: string };
        return {
          released: await expireHold(this.prisma, bookingId, new Date()),
        };
      }
      case Jobs.matchPromptResult: {
        const { matchId } = job.data as { matchId: string };
        const notes = await promptMatchResult(this.prisma, matchId, new Date());
        if (notes.length) {
          await this.queue.add(
            Jobs.pushSend,
            { notificationIds: notes.map((n) => n.id) },
            { attempts: 3, removeOnComplete: true, removeOnFail: 100 },
          );
        }
        return { prompted: notes.length };
      }
      case Jobs.pushSend: {
        const { notificationIds } = job.data as { notificationIds: string[] };
        return { sent: await this.push.sendNotifications(notificationIds) };
      }
      case Jobs.postSchedulePublish: {
        const { scheduleId } = job.data as { scheduleId: string };
        const result = await publishPostSchedule(this.prisma, scheduleId);
        if (result.nextAt) {
          await this.queue.add(Jobs.postSchedulePublish, { scheduleId }, {
            jobId: postScheduleJobId(scheduleId, result.nextAt),
            delay: Math.max(0, result.nextAt.getTime() - Date.now()),
            attempts: 3, removeOnComplete: true, removeOnFail: 100,
          });
        }
        return result;
      }
      case Jobs.mediaCleanup:
        return { deleted: await this.media.cleanupExpired() };
      default:
        throw new Error(`Job không xác định: ${job.name}`);
    }
  }
}
