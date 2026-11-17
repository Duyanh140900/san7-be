import type { Queue } from 'bullmq';
import { Jobs } from '../queue/queue.constants.js';
import { SystemProcessor } from './system.processor.js';
import * as schedules from '../schedules/schedules.service.js';

describe('SystemProcessor post schedule', () => {
  it('lịch tuần tạo job cho kỳ kế tiếp với occurrence ID mới, không dùng lại job đang active', async () => {
    const nextAt = new Date('2026-11-24T10:00:00.000Z');
    const queue = { add: vi.fn().mockResolvedValue({}) };
    const processor = new SystemProcessor(
      {} as never,
      {} as never,
      queue as unknown as Queue,
    );
    vi.spyOn(schedules, 'publishPostSchedule').mockResolvedValue({ published: true, nextAt });

    await processor.process({ name: Jobs.postSchedulePublish, data: { scheduleId: 's1' } } as never);

    expect(queue.add).toHaveBeenCalledWith(
      Jobs.postSchedulePublish,
      { scheduleId: 's1' },
      expect.objectContaining({
        jobId: schedules.postScheduleJobId('s1', nextAt),
        delay: expect.any(Number),
      }),
    );
  });
});
