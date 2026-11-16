import {
  CanActivate,
  ExecutionContext,
  HttpStatus,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppError } from '../common/errors.js';
import { setupApp } from '../setup-app.js';
import { ChatController } from './chat.controller.js';
import { ChatService } from './chat.service.js';

const matchId = '11111111-1111-4111-8111-111111111111';
const userId = '33333333-3333-4333-8333-333333333333';

class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest().user = { userId };
    return true;
  }
}

describe('ChatController (e2e)', () => {
  let app: INestApplication;
  const chat = { send: vi.fn(), list: vi.fn() };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [ChatController],
      providers: [{ provide: ChatService, useValue: chat }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalGuards(new TestAuthGuard());
    setupApp(app);
    await app.init();
  });

  afterAll(async () => app.close());
  beforeEach(() => vi.clearAllMocks());

  it('POST /v1/matches/:id/messages trim body và chuyển đúng user', async () => {
    chat.send.mockResolvedValue({ id: 'm1' });
    await request(app.getHttpServer())
      .post(`/v1/matches/${matchId}/messages`)
      .send({ body: '  chào hai đội  ' })
      .expect(201);
    expect(chat.send).toHaveBeenCalledWith(userId, matchId, {
      body: 'chào hai đội',
    });
  });

  it('POST body rỗng hoặc quá 1000 ký tự → 400', async () => {
    await request(app.getHttpServer())
      .post(`/v1/matches/${matchId}/messages`)
      .send({ body: '   ' })
      .expect(400);
    await request(app.getHttpServer())
      .post(`/v1/matches/${matchId}/messages`)
      .send({ body: 'a'.repeat(1001) })
      .expect(400);
    expect(chat.send).not.toHaveBeenCalled();
  });

  it('matchId không phải UUID → 400', async () => {
    await request(app.getHttpServer())
      .get('/v1/matches/abc/messages')
      .expect(400);
  });

  it('người ngoài hai đội → 403 chat_forbidden theo định dạng lỗi chung', async () => {
    chat.list.mockRejectedValue(
      new AppError(HttpStatus.FORBIDDEN, 'chat_forbidden', 'Không có quyền'),
    );
    const res = await request(app.getHttpServer())
      .get(`/v1/matches/${matchId}/messages`)
      .expect(403);
    expect(res.body).toMatchObject({
      statusCode: 403,
      code: 'chat_forbidden',
    });
  });

  it('GET phân trang: truyền cursor và limit đã ép kiểu', async () => {
    chat.list.mockResolvedValue({ items: [] });
    await request(app.getHttpServer())
      .get(`/v1/matches/${matchId}/messages?limit=10&cursor=${matchId}`)
      .expect(200);
    expect(chat.list).toHaveBeenCalledWith(userId, matchId, {
      limit: 10,
      cursor: matchId,
    });
  });
});
