import { CanActivate, ExecutionContext, INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { TeamMemberGuard } from '../common/team-member.guard.js';
import { setupApp } from '../setup-app.js';
import { PostSchedulesController } from './schedules.controller.js';
import { PostSchedulesService } from './schedules.service.js';

const teamId = '11111111-1111-4111-8111-111111111111';
const scheduleId = '22222222-2222-4222-8222-222222222222';

class TestTeamGuard implements CanActivate {
  canActivate(ctx: ExecutionContext) {
    const req = ctx.switchToHttp().getRequest();
    req.membership = { teamId, userId: '33333333-3333-4333-8333-333333333333', role: 'captain' };
    return true;
  }
}

describe('PostSchedulesController (e2e)', () => {
  let app: INestApplication;
  const schedules = { create: vi.fn(), list: vi.fn(), update: vi.fn(), cancel: vi.fn() };
  beforeAll(async () => {
    const module = await Test.createTestingModule({ controllers: [PostSchedulesController], providers: [{ provide: PostSchedulesService, useValue: schedules }] })
      .overrideGuard(TeamMemberGuard).useValue(new TestTeamGuard()).compile();
    app = module.createNestApplication(); setupApp(app); await app.init();
  });
  afterAll(async () => app.close());
  beforeEach(() => vi.clearAllMocks());
  const payload = { type: 'find_opponent', startAt: '2026-11-18T19:00:00.000Z', endAt: '2026-11-18T20:30:00.000Z', level: 'tb', deal: 'friendly', scheduledAt: '2026-11-17T10:00:00.000Z', repeatWeekly: true };
  it('POST tạo lịch sau khi kiểm tra body', async () => {
    schedules.create.mockResolvedValue({ id: scheduleId });
    await request(app.getHttpServer()).post(`/v1/teams/${teamId}/post-schedules`).send(payload).expect(201).expect({ id: scheduleId });
    expect(schedules.create).toHaveBeenCalledWith(expect.objectContaining({ teamId }), expect.objectContaining({ repeatWeekly: true, scheduledAt: new Date(payload.scheduledAt) }));
  });
  it('GET trả danh sách lịch đăng của đội', async () => {
    schedules.list.mockResolvedValue([{ id: scheduleId }]);
    await request(app.getHttpServer()).get(`/v1/teams/${teamId}/post-schedules`).expect(200).expect([{ id: scheduleId }]);
    expect(schedules.list).toHaveBeenCalledWith(expect.objectContaining({ teamId }));
  });
  it('DELETE hủy lịch theo UUID', async () => {
    await request(app.getHttpServer()).delete(`/v1/teams/${teamId}/post-schedules/${scheduleId}`).expect(204);
    expect(schedules.cancel).toHaveBeenCalledWith(expect.objectContaining({ teamId }), scheduleId);
  });
});
