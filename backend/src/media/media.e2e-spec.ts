import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { HttpStatus } from '@nestjs/common';
import { AppError } from '../common/errors.js';
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
  const media = { createImageUpload: vi.fn(), finalizeUpload: vi.fn(), readReceipt: vi.fn(), readPublicImage: vi.fn() };

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

  it('validate: purpose lạ, size 0, thiếu trường → 400', async () => {
    const bad = [
      { purpose: 'x', contentType: 'image/png', size: 10 },
      { purpose: 'post', contentType: 'image/png', size: 0 },
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

  it('size quá 10MB được service trả 413 media_too_large', async () => {
    media.createImageUpload.mockRejectedValue(new AppError(HttpStatus.PAYLOAD_TOO_LARGE, 'media_too_large', 'Ảnh tối đa 10MB'));
    await request(app.getHttpServer())
      .post('/v1/media/uploads')
      .send({ purpose: 'post', contentType: 'image/png', size: 10 * 1024 * 1024 + 1 })
      .expect(413)
      .expect((response) => {
        expect(response.body).toMatchObject({ code: 'media_too_large' });
      });
    expect(media.createImageUpload).toHaveBeenCalled();
  });

  it('purpose receipt được nhận', async () => {
    media.createImageUpload.mockResolvedValue({ key: 'receipt-key' });
    await request(app.getHttpServer())
      .post('/v1/media/uploads')
      .send({ purpose: 'receipt', contentType: 'image/jpeg', size: 1000 })
      .expect(201);
  });

  it('purpose receipt nhận teamId UUID, từ chối teamId không hợp lệ', async () => {
    media.createImageUpload.mockResolvedValue({ key: 'receipt-key' });
    const teamId = '66666666-6666-4666-8666-666666666666';
    await request(app.getHttpServer()).post('/v1/media/uploads').send({ purpose: 'receipt', contentType: 'image/png', size: 10, teamId }).expect(201);
    expect(media.createImageUpload).toHaveBeenCalledWith(userId, expect.objectContaining({ teamId }));
    await request(app.getHttpServer()).post('/v1/media/uploads').send({ purpose: 'receipt', contentType: 'image/png', size: 10, teamId: 'x' }).expect(400);
  });

  it('POST /v1/media/uploads/finalize chuyển đúng user và key', async () => {
    media.finalizeUpload.mockResolvedValue({ key: 'public/a.webp', url: 'u' });
    await request(app.getHttpServer()).post('/v1/media/uploads/finalize').send({ key: 'public/a.webp' }).expect(200).expect({ key: 'public/a.webp', url: 'u' });
    expect(media.finalizeUpload).toHaveBeenCalledWith(userId, 'public/a.webp');
    await request(app.getHttpServer()).post('/v1/media/uploads/finalize').send({}).expect(400);
  });

  it('GET /v1/media/receipts/:id truyền user đăng nhập; 403 khi không thuộc đội', async () => {
    const id = '55555555-5555-4555-8555-555555555555';
    media.readReceipt.mockRejectedValue(new AppError(HttpStatus.FORBIDDEN, 'media_forbidden', 'Chỉ thành viên đội được xem biên lai'));
    await request(app.getHttpServer()).get(`/v1/media/receipts/${id}`).expect(403);
    expect(media.readReceipt).toHaveBeenCalledWith(userId, id);
    await request(app.getHttpServer()).get('/v1/media/receipts/not-a-uuid').expect(400);
  });
});
