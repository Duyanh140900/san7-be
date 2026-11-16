import {
  CanActivate,
  ExecutionContext,
  INestApplication,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { setupApp } from '../setup-app.js';
import { CommunityController } from './community.controller.js';
import { CommunityService } from './community.service.js';

const postId = '11111111-1111-4111-8111-111111111111';
const userId = '33333333-3333-4333-8333-333333333333';

class TestAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    context.switchToHttp().getRequest().user = { userId };
    return true;
  }
}

describe('CommunityController (e2e)', () => {
  let app: INestApplication;
  const community = {
    createComment: vi.fn(),
    listComments: vi.fn(),
    deleteComment: vi.fn(),
    setReaction: vi.fn(),
    removeReaction: vi.fn(),
    listReactions: vi.fn(),
  };

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [CommunityController],
      providers: [{ provide: CommunityService, useValue: community }],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalGuards(new TestAuthGuard());
    setupApp(app);
    await app.init();
  });

  afterAll(async () => app.close());

  beforeEach(() => vi.clearAllMocks());

  it('POST /v1/posts/:postId/comments chuyển đúng user và body đã validate', async () => {
    community.createComment.mockResolvedValue({
      id: 'c1',
      body: 'Nhận kèo',
      author: {},
    });

    await request(app.getHttpServer())
      .post(`/v1/posts/${postId}/comments`)
      .send({ body: 'Nhận kèo' })
      .expect(201)
      .expect({ id: 'c1', body: 'Nhận kèo', author: {} });

    expect(community.createComment).toHaveBeenCalledWith(userId, postId, {
      body: 'Nhận kèo',
    });
  });

  it('PUT /v1/posts/:postId/reaction reject body sai và nhận loại hợp lệ', async () => {
    await request(app.getHttpServer())
      .put(`/v1/posts/${postId}/reaction`)
      .send({ kind: 'invalid' })
      .expect(400);

    await request(app.getHttpServer())
      .put(`/v1/posts/${postId}/reaction`)
      .send({ kind: 'love' })
      .expect(204);

    expect(community.setReaction).toHaveBeenCalledWith(userId, postId, {
      kind: 'love',
    });
  });

  it('GET /v1/posts/:postId/reactions truyền lọc theo loại và phân trang', async () => {
    community.listReactions.mockResolvedValue({ counts: [], items: [] });

    await request(app.getHttpServer())
      .get(`/v1/posts/${postId}/reactions?kind=fire&limit=10`)
      .expect(200)
      .expect({ counts: [], items: [] });

    expect(community.listReactions).toHaveBeenCalledWith(userId, postId, {
      kind: 'fire',
      limit: 10,
    });
  });
});
