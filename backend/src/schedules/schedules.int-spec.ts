import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { config as loadEnv } from 'dotenv';
import { Queue, Worker } from 'bullmq';
import { Redis } from 'ioredis';
import pg from 'pg';
import type { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service.js';
import { SystemProcessor } from '../jobs/system.processor.js';
import { Jobs, SYSTEM_QUEUE } from '../queue/queue.constants.js';
import { postScheduleJobId } from './schedules.service.js';

/**
 * Tích hợp BullMQ + Postgres thật. Mỗi lần chạy dùng database và prefix Redis
 * riêng để không đụng worker/dữ liệu đang chạy. Bỏ qua nếu thiếu Redis hoặc Postgres.
 */
loadEnv({ path: '../.env', quiet: true });
const BASE_DB = process.env.TEST_DATABASE_URL ?? process.env.DATABASE_URL ?? '';
const REDIS_URL = process.env.TEST_REDIS_URL ?? process.env.REDIS_URL ?? '';

async function probe(): Promise<boolean> {
  if (!BASE_DB || !REDIS_URL) return false;
  const redis = new Redis(REDIS_URL, { lazyConnect: true, maxRetriesPerRequest: 1, retryStrategy: () => null });
  redis.on('error', () => undefined);
  const client = new pg.Client({ connectionString: BASE_DB });
  client.on('error', () => undefined);
  try {
    await redis.connect();
    await redis.ping();
    await client.connect();
    return true;
  } catch {
    return false;
  } finally {
    redis.disconnect();
    await client.end().catch(() => undefined);
  }
}

const available = await probe();
const WEEK_MS = 7 * 24 * 60 * 60 * 1000;

describe.skipIf(!available)('lịch đăng kèo: BullMQ + Postgres thật', () => {
  const suffix = randomBytes(4).toString('hex');
  const dbName = `san7_it_${suffix}`;
  const prefix = `san7-it-${suffix}`;
  let prisma: PrismaService;
  let redis: Redis;
  let queue: Queue;
  let workers: Worker[] = [];
  let teamId: string;
  let userId: string;

  const adminUrl = () => {
    const url = new URL(BASE_DB);
    url.search = '';
    return url;
  };

  beforeAll(async () => {
    const adminClient = new pg.Client({ connectionString: adminUrl().toString() });
    await adminClient.connect();
    await adminClient.query(`CREATE DATABASE "${dbName}"`);
    await adminClient.end();

    const testUrl = adminUrl();
    testUrl.pathname = `/${dbName}`;
    execFileSync('npx', ['prisma', 'migrate', 'deploy'], {
      env: { ...process.env, DATABASE_URL: testUrl.toString() },
      stdio: 'pipe',
      shell: true,
    });

    prisma = new PrismaService({ get: () => testUrl.toString() } as unknown as ConfigService<never, true>);
    redis = new Redis(REDIS_URL, { maxRetriesPerRequest: null });
    queue = new Queue(SYSTEM_QUEUE, { connection: redis, prefix });

    const user = await prisma.user.create({ data: { googleSub: `g-${suffix}`, email: `${suffix}@test.local`, name: 'Đội trưởng' } });
    const team = await prisma.team.create({
      data: { name: 'FC Test', crestColor: '#112233', area: 'Cầu Giấy', level: 'tb', inviteCode: `IT${suffix}`, createdById: user.id },
    });
    await prisma.teamMember.create({ data: { teamId: team.id, userId: user.id, role: 'captain', status: 'active', joinedAt: new Date() } });
    userId = user.id;
    teamId = team.id;
  });

  afterEach(async () => {
    await Promise.all(workers.map((w) => w.close(true)));
    workers = [];
    await queue.obliterate({ force: true });
    await prisma.postSchedule.deleteMany();
    await prisma.post.deleteMany();
  });

  afterAll(async () => {
    await queue?.close();
    redis?.disconnect();
    await prisma?.$disconnect();
    const adminClient = new pg.Client({ connectionString: adminUrl().toString() });
    await adminClient.connect();
    await adminClient.query(`DROP DATABASE IF EXISTS "${dbName}" WITH (FORCE)`);
    await adminClient.end();
  });

  function startWorker(): Worker {
    const processor = new SystemProcessor(prisma, {} as never, {} as never, queue);
    const worker = new Worker(SYSTEM_QUEUE, (job) => processor.process(job), {
      connection: new Redis(REDIS_URL, { maxRetriesPerRequest: null }),
      prefix,
    });
    workers.push(worker);
    return worker;
  }

  async function seedSchedule(repeatWeekly: boolean) {
    const now = Date.now();
    const startAt = new Date(now + 24 * 60 * 60 * 1000);
    const scheduledAt = new Date(now - 1000);
    const payload = {
      type: 'find_opponent',
      startAt: startAt.toISOString(),
      endAt: new Date(startAt.getTime() + 90 * 60_000).toISOString(),
      level: 'tb',
      deal: 'friendly',
    };
    const row = await prisma.postSchedule.create({ data: { teamId, authorId: userId, payload, scheduledAt, repeatWeekly } });
    return { row, startAt, scheduledAt };
  }

  async function until<T>(fn: () => Promise<T | null | false>, timeoutMs = 15_000): Promise<T> {
    const deadline = Date.now() + timeoutMs;
    for (;;) {
      const value = await fn();
      if (value) return value;
      if (Date.now() > deadline) throw new Error('hết thời gian chờ điều kiện');
      await new Promise((r) => setTimeout(r, 100));
    }
  }

  function bothCompleted(a: Worker, b: Worker): Promise<void> {
    return new Promise((resolve) => {
      let finished = 0;
      for (const w of [a, b]) w.on('completed', () => { if (++finished === 2) resolve(); });
    });
  }

  it('lịch lặp tuần: đăng bài và tạo job + lịch cho kỳ kế tiếp', async () => {
    const { row, startAt, scheduledAt } = await seedSchedule(true);
    startWorker();
    await queue.add(Jobs.postSchedulePublish, { scheduleId: row.id }, { jobId: postScheduleJobId(row.id, scheduledAt) });

    const next = await until(async () => {
      const s = await prisma.postSchedule.findUniqueOrThrow({ where: { id: row.id } });
      return s.scheduledAt.getTime() > scheduledAt.getTime() ? s : null;
    });
    const nextAt = new Date(scheduledAt.getTime() + WEEK_MS);
    expect(next.status).toBe('scheduled');
    expect(next.scheduledAt).toEqual(nextAt);
    expect((next.payload as { startAt: string }).startAt).toBe(new Date(startAt.getTime() + WEEK_MS).toISOString());
    expect(await prisma.post.count({ where: { teamId } })).toBe(1);

    const nextJob = await until(() => queue.getJob(postScheduleJobId(row.id, nextAt)).then((j) => j ?? null));
    expect(await nextJob.getState()).toBe('delayed');
    expect(nextJob.data).toEqual({ scheduleId: row.id });
  });

  it('hai worker nhận trùng cùng một lịch một lần: chỉ đăng một bài', async () => {
    const { row, scheduledAt } = await seedSchedule(false);
    const a = startWorker();
    const b = startWorker();
    const done = bothCompleted(a, b);
    // Giao trùng: hai job khác ID cùng trỏ vào một lịch, hai worker xử lý song song.
    await Promise.all([
      queue.add(Jobs.postSchedulePublish, { scheduleId: row.id }, { jobId: `dup-a-${postScheduleJobId(row.id, scheduledAt)}` }),
      queue.add(Jobs.postSchedulePublish, { scheduleId: row.id }, { jobId: `dup-b-${postScheduleJobId(row.id, scheduledAt)}` }),
    ]);
    await done;

    expect(await prisma.post.count({ where: { teamId } })).toBe(1);
    const final = await prisma.postSchedule.findUniqueOrThrow({ where: { id: row.id } });
    expect(final.status).toBe('cancelled');
    expect(final.publishedPostId).not.toBeNull();
  });

  it('hai worker song song trên lịch lặp tuần: một bài, chỉ dời đúng một kỳ', async () => {
    const { row, scheduledAt } = await seedSchedule(true);
    const a = startWorker();
    const b = startWorker();
    const done = bothCompleted(a, b);
    await Promise.all([
      queue.add(Jobs.postSchedulePublish, { scheduleId: row.id }, { jobId: `w-a-${row.id}` }),
      queue.add(Jobs.postSchedulePublish, { scheduleId: row.id }, { jobId: `w-b-${row.id}` }),
    ]);
    await done;

    expect(await prisma.post.count({ where: { teamId } })).toBe(1);
    const final = await prisma.postSchedule.findUniqueOrThrow({ where: { id: row.id } });
    expect(final.scheduledAt).toEqual(new Date(scheduledAt.getTime() + WEEK_MS));
    expect(final.status).toBe('scheduled');
  });
});
