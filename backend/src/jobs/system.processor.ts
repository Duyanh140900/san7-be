import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import type { Job } from 'bullmq';

export const SYSTEM_QUEUE = 'system';

/** Hàng đợi hệ thống. M0 chỉ có job 'ping' để kiểm tra worker sống; các job thật thêm từ M2. */
@Processor(SYSTEM_QUEUE)
export class SystemProcessor extends WorkerHost {
  private readonly logger = new Logger(SystemProcessor.name);

  async process(job: Job): Promise<unknown> {
    switch (job.name) {
      case 'ping':
        this.logger.log(`ping ${job.id}`);
        return { pong: true };
      default:
        throw new Error(`Job không xác định: ${job.name}`);
    }
  }
}
