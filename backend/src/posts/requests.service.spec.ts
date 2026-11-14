import type { Queue } from 'bullmq';
import type { TeamMembership } from '../common/team-member.guard.js';
import type { NotificationsService } from '../notifications/notifications.service.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { expireRequest, RequestsService } from './requests.service.js';

const HOUR = 3_600_000;
const owner: TeamMembership = {
  teamId: 'own',
  userId: 'cap1',
  role: 'captain',
};
const guest: TeamMembership = { teamId: 'gst', userId: 'cap2', role: 'vice' };

const team = (id: string, name: string) => ({
  id,
  name,
  crestColor: '#0066CC',
  area: 'Cầu Giấy',
  level: 'tb',
});

function post(over: Record<string, unknown> = {}) {
  return {
    id: 'p1',
    teamId: 'own',
    type: 'find_opponent',
    status: 'open',
    startAt: new Date(Date.now() + 24 * HOUR),
    endAt: new Date(Date.now() + 25.5 * HOUR),
    pitchName: 'Phúc La',
    ratioWin: 40,
    ratioLose: 60,
    team: team('own', 'FC Cầu Giấy'),
    ...over,
  };
}

function request(over: Record<string, unknown> = {}) {
  return {
    id: 'r1',
    postId: 'p1',
    teamId: 'gst',
    status: 'pending',
    expiresAt: new Date(Date.now() + HOUR),
    createdAt: new Date(),
    peopleCount: 9,
    ratioWin: null,
    ratioLose: null,
    message: null,
    team: team('gst', 'FC Mỹ Đình'),
    post: post(),
    ...over,
  };
}

function setup() {
  let n = 0;
  const tx = {
    $queryRaw: vi.fn().mockResolvedValue([]),
    post: { findUnique: vi.fn(), update: vi.fn() },
    matchRequest: {
      findUnique: vi.fn(),
      findUniqueOrThrow: vi.fn(),
      findFirst: vi.fn().mockResolvedValue(null),
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn((args: { data: Record<string, unknown> }) =>
        Promise.resolve({
          id: 'new',
          status: 'pending',
          team: { name: 'FC Mỹ Đình' },
          ...args.data,
        }),
      ),
      update: vi.fn(),
      updateMany: vi.fn().mockResolvedValue({ count: 1 }),
    },
    match: { create: vi.fn().mockResolvedValue({ id: 'm1' }) },
    event: {
      create: vi.fn((args: { data: { teamId: string } }) =>
        Promise.resolve({ id: `e-${args.data.teamId}-${++n}` }),
      ),
    },
    teamMember: {
      findMany: vi.fn((args: { where: { teamId: string } }) =>
        Promise.resolve([{ userId: `mgr-${args.where.teamId}` }]),
      ),
    },
    notification: {
      updateMany: vi.fn(),
      createManyAndReturn: vi.fn(
        (args: { data: { userId: string; type: string }[] }) =>
          Promise.resolve(
            args.data.map((d) => ({ id: `n-${d.userId}`, ...d })),
          ),
      ),
    },
  };
  const prisma = {
    $transaction: vi.fn((fn: (t: typeof tx) => unknown) => fn(tx)),
  };
  const notifications = { dispatch: vi.fn() };
  const realtime = { toTeam: vi.fn() };
  const queue = { add: vi.fn() };
  const service = new RequestsService(
    prisma as unknown as PrismaService,
    notifications as unknown as NotificationsService,
    realtime as unknown as RealtimeService,
    queue as unknown as Queue,
  );
  return { service, tx, prisma, notifications, realtime, queue };
}

const notes = (tx: ReturnType<typeof setup>['tx']) =>
  tx.notification.createManyAndReturn.mock.calls.flatMap(
    (c: unknown[]) =>
      (c[0] as { data: { userId: string; type: string }[] }).data,
  );

describe('RequestsService.send', () => {
  it('gửi yêu cầu: khoá kèo, hạn 2 giờ, báo đội đăng, hẹn job hết hạn', async () => {
    const { service, tx, notifications, queue } = setup();
    tx.post.findUnique.mockResolvedValue(post());
    const r = await service.send(guest, 'p1', {
      peopleCount: 9,
      ratioWin: 40,
      ratioLose: 60,
      message: 'Đến đúng giờ',
    });
    expect(tx.$queryRaw).toHaveBeenCalled();
    const data = tx.matchRequest.create.mock.calls[0][0].data;
    // trùng tỷ lệ của kèo = đồng ý, không lưu đề xuất
    expect(data.ratioWin).toBeNull();
    const ttl = (data.expiresAt as Date).getTime() - Date.now();
    expect(ttl).toBeGreaterThan(1.9 * HOUR);
    expect(ttl).toBeLessThanOrEqual(2 * HOUR);
    expect(notes(tx)).toEqual([
      expect.objectContaining({ userId: 'mgr-own', type: 'request.received' }),
    ]);
    expect(notifications.dispatch).toHaveBeenCalled();
    expect(queue.add).toHaveBeenCalledWith(
      'request.expire',
      { requestId: 'new' },
      expect.objectContaining({ jobId: 'request-expire-new' }),
    );
    expect(r.status).toBe('pending');
  });

  it('hạn không quá giờ đá', async () => {
    const { service, tx } = setup();
    const startAt = new Date(Date.now() + 0.5 * HOUR);
    tx.post.findUnique.mockResolvedValue(post({ startAt }));
    await service.send(guest, 'p1', { peopleCount: 7 });
    expect(tx.matchRequest.create.mock.calls[0][0].data.expiresAt).toEqual(
      startAt,
    );
  });

  it('chặn: kèo của chính đội, kèo đã chốt, gửi trùng, tuyển người', async () => {
    const { service, tx } = setup();
    tx.post.findUnique.mockResolvedValue(post({ teamId: 'gst' }));
    await expect(
      service.send(guest, 'p1', { peopleCount: 9 }),
    ).rejects.toMatchObject({
      response: { code: 'own_post' },
    });
    tx.post.findUnique.mockResolvedValue(post({ status: 'matched' }));
    await expect(
      service.send(guest, 'p1', { peopleCount: 9 }),
    ).rejects.toMatchObject({
      status: 409,
      response: { code: 'post_not_open' },
    });
    tx.post.findUnique.mockResolvedValue(post());
    tx.matchRequest.findFirst.mockResolvedValue({ id: 'old' });
    await expect(
      service.send(guest, 'p1', { peopleCount: 9 }),
    ).rejects.toMatchObject({
      response: { code: 'request_exists' },
    });
    tx.post.findUnique.mockResolvedValue(post({ type: 'recruit' }));
    await expect(
      service.send(guest, 'p1', { peopleCount: 9 }),
    ).rejects.toMatchObject({
      response: { code: 'not_requestable' },
    });
  });

  it('tỷ lệ đề xuất phải đủ hai số và cộng bằng 100', async () => {
    const { service } = setup();
    await expect(
      service.send(guest, 'p1', { peopleCount: 9, ratioWin: 50 }),
    ).rejects.toMatchObject({ response: { code: 'invalid_ratio' } });
    await expect(
      service.send(guest, 'p1', {
        peopleCount: 9,
        ratioWin: 50,
        ratioLose: 60,
      }),
    ).rejects.toMatchObject({ response: { code: 'invalid_ratio' } });
  });
});

describe('RequestsService.accept', () => {
  it('chốt kèo: tạo trận + lịch hai đội, từ chối đội khác, báo tất cả', async () => {
    const { service, tx, realtime, notifications } = setup();
    tx.matchRequest.findUnique.mockResolvedValue({ postId: 'p1' });
    tx.matchRequest.findUniqueOrThrow.mockResolvedValue(request());
    tx.matchRequest.findMany.mockResolvedValue([{ id: 'r2', teamId: 'other' }]);

    const res = await service.accept(owner, 'r1');

    expect(tx.$queryRaw).toHaveBeenCalled();
    expect(tx.matchRequest.update).toHaveBeenCalledWith({
      where: { id: 'r1' },
      data: expect.objectContaining({ status: 'accepted' }),
    });
    expect(tx.post.update).toHaveBeenCalledWith({
      where: { id: 'p1' },
      data: { status: 'matched' },
    });
    expect(tx.match.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ homeTeamId: 'own', awayTeamId: 'gst' }),
    });
    const events = tx.event.create.mock.calls.map((c) => c[0].data);
    expect(events).toEqual([
      expect.objectContaining({
        teamId: 'own',
        kind: 'match',
        title: 'vs FC Mỹ Đình',
        matchId: 'm1',
      }),
      expect.objectContaining({
        teamId: 'gst',
        kind: 'match',
        title: 'vs FC Cầu Giấy',
        matchId: 'm1',
      }),
    ]);
    expect(tx.matchRequest.updateMany).toHaveBeenCalledWith({
      where: { id: { in: ['r2'] } },
      data: expect.objectContaining({ status: 'declined' }),
    });
    expect(notes(tx).map((n) => [n.userId, n.type])).toEqual([
      ['mgr-gst', 'request.accepted'],
      ['mgr-other', 'request.declined'],
    ]);
    // thông báo 'muốn nhận kèo' của cả hai yêu cầu không còn nhắc xác nhận
    expect(tx.notification.updateMany.mock.calls[0][0].where.OR).toHaveLength(
      2,
    );
    expect(realtime.toTeam).toHaveBeenCalledWith('own', 'events.changed', {});
    expect(realtime.toTeam).toHaveBeenCalledWith('gst', 'events.changed', {});
    expect(notifications.dispatch).toHaveBeenCalledTimes(1);
    expect(res).toEqual({
      matchId: 'm1',
      eventId: expect.stringMatching(/^e-own/),
    });
  });

  it('pass sân: không tạo trận, chỉ đội nhận sân có lịch', async () => {
    const { service, tx } = setup();
    tx.matchRequest.findUnique.mockResolvedValue({ postId: 'p1' });
    tx.matchRequest.findUniqueOrThrow.mockResolvedValue(
      request({ post: post({ type: 'pass_pitch' }) }),
    );
    const res = await service.accept(owner, 'r1');
    expect(tx.match.create).not.toHaveBeenCalled();
    expect(tx.event.create).toHaveBeenCalledTimes(1);
    expect(tx.event.create.mock.calls[0][0].data).toMatchObject({
      teamId: 'gst',
      kind: 'other',
    });
    expect(res.eventId).toBeUndefined();
  });

  it('không chấp nhận được: yêu cầu hết hạn, kèo đã chốt, đội khác', async () => {
    const { service, tx } = setup();
    tx.matchRequest.findUnique.mockResolvedValue({ postId: 'p1' });
    tx.matchRequest.findUniqueOrThrow.mockResolvedValue(
      request({ expiresAt: new Date(Date.now() - 1) }),
    );
    await expect(service.accept(owner, 'r1')).rejects.toMatchObject({
      status: 409,
      response: { code: 'request_not_pending' },
    });
    tx.matchRequest.findUniqueOrThrow.mockResolvedValue(
      request({ post: post({ status: 'matched' }) }),
    );
    await expect(service.accept(owner, 'r1')).rejects.toMatchObject({
      response: { code: 'post_not_open' },
    });
    await expect(service.accept(guest, 'r1')).rejects.toMatchObject({
      status: 404,
    });
    expect(tx.match.create).not.toHaveBeenCalled();
  });
});

describe('RequestsService.decline / cancel', () => {
  it('từ chối: báo đội gửi; chỉ đội đăng kèo được từ chối', async () => {
    const { service, tx } = setup();
    tx.matchRequest.findUnique.mockResolvedValue(request());
    await service.decline(owner, 'r1');
    expect(notes(tx)).toEqual([
      expect.objectContaining({ userId: 'mgr-gst', type: 'request.declined' }),
    ]);
    await expect(service.decline(guest, 'r1')).rejects.toMatchObject({
      status: 404,
    });
  });

  it('huỷ: chỉ đội gửi; đã trả lời thì 409', async () => {
    const { service, tx } = setup();
    tx.matchRequest.findUnique.mockResolvedValue(request());
    await service.cancel(guest, 'r1');
    expect(notes(tx)).toEqual([
      expect.objectContaining({ userId: 'mgr-own', type: 'request.cancelled' }),
    ]);
    await expect(service.cancel(owner, 'r1')).rejects.toMatchObject({
      status: 404,
    });
    tx.matchRequest.updateMany.mockResolvedValue({ count: 0 });
    await expect(service.cancel(guest, 'r1')).rejects.toMatchObject({
      status: 409,
    });
  });
});

describe('expireRequest', () => {
  it('chỉ hết hạn yêu cầu còn chờ và đã quá hạn', async () => {
    const { prisma, tx } = setup();
    tx.matchRequest.findUnique.mockResolvedValue(
      request({ expiresAt: new Date(Date.now() - 1000) }),
    );
    const rows = await expireRequest(prisma as never, 'r1', new Date());
    expect(rows).toHaveLength(1);
    expect(tx.matchRequest.updateMany).toHaveBeenCalledWith({
      where: { id: 'r1', status: 'pending' },
      data: { status: 'expired' },
    });

    tx.matchRequest.updateMany.mockClear();
    tx.matchRequest.findUnique.mockResolvedValue(request()); // chưa tới hạn
    expect(await expireRequest(prisma as never, 'r1', new Date())).toEqual([]);
    tx.matchRequest.findUnique.mockResolvedValue(
      request({ status: 'accepted', expiresAt: new Date(0) }),
    );
    expect(await expireRequest(prisma as never, 'r1', new Date())).toEqual([]);
    expect(tx.matchRequest.updateMany).not.toHaveBeenCalled();
  });
});
