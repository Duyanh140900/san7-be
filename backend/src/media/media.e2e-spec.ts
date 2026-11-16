import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { setupApp } from '../setup-app.js';
import { MediaController } from './media.controller.js';
import { MediaService } from './media.service.js';

const userId = '33333333-3333-4333-8333-333333333333';

class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest().user = { userId };
    return true;
  }
}

describe('MediaController (e2e)', () => {
  let app: INestApplication;
  const media = { createImageUpload: vi.fn() };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [MediaController],
      providers: [{ provide: MediaService, useValue: media }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalGuards(new TestAuthGuard());
    setupApp(app);
    await app.init();
  });

  afterAll(async () => app.close());
  beforeEach(() => vi.clearAllMocks());

  it('POST /v1/media/uploads chuyển đúng user và body', async () => {
    media.createImageUpload.mockResolvedValue({ key: 'k' });
    await request(app.getHttpServer())
      .post('/v1/media/uploads')
      .send({ purpose: 'post', contentType: 'image/jpeg', size: 1000 })
      .expect(201);
    expect(media.createImageUpload).toHaveBeenCalledWith(userId, {
      purpose: 'post',
      contentType: 'image/jpeg',
      size: 1000,
    });
  });

  it('validate: purpose lạ, size 0, size quá 10MB, thiếu trường → 400', async () => {
    const bad = [
      { purpose: 'x', contentType: 'image/png', size: 10 },
      { purpose: 'post', contentType: 'image/png', size: 0 },
      { purpose: 'post', contentType: 'image/png', size: 10 * 1024 * 1024 + 1 },
      { purpose: 'post', size: 10 },
    ];
    for (const body of bad) {
      await request(app.getHttpServer())
        .post('/v1/media/uploads')
        .send(body)
        .expect(400);
    }
    expect(media.createImageUpload).not.toHaveBeenCalled();
  });
});
