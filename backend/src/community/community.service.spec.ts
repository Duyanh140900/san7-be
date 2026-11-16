import { ReactionKind, ReactionTarget } from '../generated/prisma/enums.js';
import type { PrismaService } from '../prisma/prisma.service.js';
import type { RealtimeService } from '../realtime/realtime.service.js';
import { CommunityService } from './community.service.js';

const postId = '11111111-1111-4111-8111-111111111111';
const commentId = '22222222-2222-4222-8222-222222222222';
const userId = '33333333-3333-4333-8333-333333333333';
const author = { id: userId, name: 'Anh A', avatarUrl: null };
const now = new Date('2026-11-16T12:00:00.000Z');

function comment(overrides: Record<string, unknown> = {}) {
  return {
    id: commentId,
    postId,
    userId,
    body: 'Đội mình nhận kèo nhé!',
    createdAt: now,
    updatedAt: now,
    user: author,
    ...overrides,
  };
}

function setup() {
  const prisma = {
    post: { findUnique: vi.fn().mockResolvedValue({ id: postId }) },
    comment: {
      create: vi.fn().mockResolvedValue(comment()),
      findMany: vi.fn().mockResolvedValue([]),
      findFirst: vi.fn(),
      delete: vi.fn().mockResolvedValue({}),
    },
    reaction: {
      upsert: vi.fn().mockResolvedValue({}),
      deleteMany: vi.fn().mockResolvedValue({ count: 1 }),
      groupBy: vi.fn().mockResolvedValue([]),
      findUnique: vi.fn().mockResolvedValue(null),
      findMany: vi.fn().mockResolvedValue([]),
    },
  };
  const realtime = { toPost: vi.fn() };
  return {
    service: new CommunityService(
      prisma as unknown as PrismaService,
      realtime as unknown as RealtimeService,
    ),
    prisma,
    realtime,
  };
}

describe('CommunityService - bình luận', () => {
  it('tạo bình luận và phát sự kiện post sau khi ghi thành công', async () => {
    const { service, prisma, realtime } = setup();
    const result = await service.createComment(userId, postId, {
      body: 'Đội mình nhận kèo nhé!',
    });

    expect(prisma.comment.create).toHaveBeenCalledWith({
      data: { postId, userId, body: 'Đội mình nhận kèo nhé!' },
      include: { user: { select: { id: true, name: true, avatarUrl: true } } },
    });
    expect(result.author).toEqual(author);
    expect(realtime.toPost).toHaveBeenCalledWith(postId, 'comment.created', {
      commentId,
    });
  });

  it('liệt kê bình luận phân trang cursor theo mới nhất', async () => {
    const { service, prisma } = setup();
    prisma.comment.findMany.mockResolvedValue([
      comment(),
      comment({ id: '44444444-4444-4444-8444-444444444444' }),
    ]);

    const result = await service.listComments(postId, {
      limit: 1,
      cursor: commentId,
    });

    expect(prisma.comment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { postId },
        take: 2,
        cursor: { id: commentId },
        skip: 1,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      }),
    );
    expect(result.items).toHaveLength(1);
    expect(result.nextCursor).toBe(commentId);
  });

  it('chỉ tác giả bình luận hoặc chủ kèo mới được xoá', async () => {
    const { service, prisma, realtime } = setup();
    prisma.comment.findFirst.mockResolvedValue(
      comment({ post: { authorId: '55555555-5555-4555-8555-555555555555' } }),
    );

    await expect(
      service.deleteComment(
        '66666666-6666-4666-8666-666666666666',
        postId,
        commentId,
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: { code: 'comment_delete_forbidden' },
    });

    await service.deleteComment(userId, postId, commentId);
    await service.deleteComment(
      '55555555-5555-4555-8555-555555555555',
      postId,
      commentId,
    );
    expect(prisma.comment.delete).toHaveBeenCalledTimes(2);
    expect(realtime.toPost).toHaveBeenLastCalledWith(
      postId,
      'comment.deleted',
      { commentId },
    );
  });
});

describe('CommunityService - cảm xúc', () => {
  it('đặt hoặc đổi cảm xúc bằng upsert; bỏ cảm xúc là idempotent', async () => {
    const { service, prisma, realtime } = setup();
    await service.setReaction(userId, postId, { kind: ReactionKind.love });
    await service.removeReaction(userId, postId);

    expect(prisma.reaction.upsert).toHaveBeenCalledWith({
      where: {
        targetType_targetId_userId: {
          targetType: ReactionTarget.post,
          targetId: postId,
          userId,
        },
      },
      create: {
        targetType: ReactionTarget.post,
        targetId: postId,
        userId,
        kind: ReactionKind.love,
      },
      update: { kind: ReactionKind.love },
    });
    expect(prisma.reaction.deleteMany).toHaveBeenCalledWith({
      where: { targetType: ReactionTarget.post, targetId: postId, userId },
    });
    expect(realtime.toPost).toHaveBeenLastCalledWith(
      postId,
      'reaction.changed',
      { userId },
    );
  });

  it('trả số lượng đủ năm loại và danh sách người theo loại có phân trang', async () => {
    const { service, prisma } = setup();
    prisma.reaction.groupBy.mockResolvedValue([
      { kind: ReactionKind.like, _count: { _all: 2 } },
      { kind: ReactionKind.fire, _count: { _all: 1 } },
    ]);
    prisma.reaction.findUnique.mockResolvedValue({ kind: ReactionKind.love });
    prisma.reaction.findMany.mockResolvedValue([
      {
        id: '77777777-7777-4777-8777-777777777777',
        kind: ReactionKind.fire,
        createdAt: now,
        user: author,
      },
      {
        id: '88888888-8888-4888-8888-888888888888',
        kind: ReactionKind.fire,
        createdAt: now,
        user: author,
      },
    ]);

    const result = await service.listReactions(userId, postId, {
      kind: ReactionKind.fire,
      limit: 1,
    });

    expect(result.counts).toEqual([
      { kind: ReactionKind.like, count: 2 },
      { kind: ReactionKind.love, count: 0 },
      { kind: ReactionKind.fire, count: 1 },
      { kind: ReactionKind.haha, count: 0 },
      { kind: ReactionKind.sad, count: 0 },
    ]);
    expect(result.myKind).toBe(ReactionKind.love);
    expect(result.items).toEqual([
      {
        id: userId,
        name: 'Anh A',
        avatarUrl: null,
        kind: ReactionKind.fire,
        reactedAt: now,
      },
    ]);
    expect(result.nextCursor).toBe('77777777-7777-4777-8777-777777777777');
    expect(prisma.reaction.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          targetType: ReactionTarget.post,
          targetId: postId,
          kind: ReactionKind.fire,
        },
        take: 2,
      }),
    );
  });

  it('bài không tồn tại trả 404 trước khi tạo hoặc xem dữ liệu cộng đồng', async () => {
    const { service, prisma } = setup();
    prisma.post.findUnique.mockResolvedValue(null);

    await expect(service.listComments(postId, {})).rejects.toMatchObject({
      status: 404,
      response: { code: 'post_not_found' },
    });
    expect(prisma.comment.findMany).not.toHaveBeenCalled();
  });
});
