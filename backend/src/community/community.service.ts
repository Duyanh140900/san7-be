import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { ReactionKind, ReactionTarget } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { RealtimeService } from '../realtime/realtime.service.js';
import type {
  CommentDto,
  CommentPageDto,
  CreateCommentDto,
  CursorPageQuery,
  ListReactionsQuery,
  ReactionPageDto,
  SetReactionDto,
} from './community.dto.js';

const commentAuthorSelect = { id: true, name: true, avatarUrl: true } as const;
const postTarget = (postId: string) => ({
  targetType: ReactionTarget.post,
  targetId: postId,
});

@Injectable()
export class CommunityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly realtime: RealtimeService,
  ) {}

  async createComment(
    userId: string,
    postId: string,
    dto: CreateCommentDto,
  ): Promise<CommentDto> {
    await this.ensurePost(postId);
    const row = await this.prisma.comment.create({
      data: { postId, userId, body: dto.body },
      include: { user: { select: commentAuthorSelect } },
    });
    const comment = this.toCommentDto(row);
    this.realtime.toPost(postId, 'comment.created', { commentId: row.id });
    return comment;
  }

  async listComments(
    postId: string,
    q: CursorPageQuery,
  ): Promise<CommentPageDto> {
    await this.ensurePost(postId);
    const limit = q.limit ?? 30;
    const rows = await this.prisma.comment.findMany({
      where: { postId },
      include: { user: { select: commentAuthorSelect } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: limit + 1,
      ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
    });
    const page = rows.slice(0, limit);
    return {
      items: page.map((row) => this.toCommentDto(row)),
      nextCursor: rows.length > limit ? page.at(-1)?.id : undefined,
    };
  }

  async deleteComment(
    userId: string,
    postId: string,
    commentId: string,
  ): Promise<void> {
    const comment = await this.prisma.comment.findFirst({
      where: { id: commentId, postId },
      include: { post: { select: { authorId: true } } },
    });
    if (!comment)
      throw this.notFound('comment_not_found', 'Không tìm thấy bình luận');
    if (comment.userId !== userId && comment.post.authorId !== userId) {
      throw new AppError(
        HttpStatus.FORBIDDEN,
        'comment_delete_forbidden',
        'Bạn không có quyền xoá bình luận này',
      );
    }
    await this.prisma.comment.delete({ where: { id: commentId } });
    this.realtime.toPost(postId, 'comment.deleted', { commentId });
  }

  async setReaction(
    userId: string,
    postId: string,
    dto: SetReactionDto,
  ): Promise<void> {
    await this.ensurePost(postId);
    await this.prisma.reaction.upsert({
      where: { targetType_targetId_userId: { ...postTarget(postId), userId } },
      create: { ...postTarget(postId), userId, kind: dto.kind },
      update: { kind: dto.kind },
    });
    this.realtime.toPost(postId, 'reaction.changed', { userId });
  }

  async removeReaction(userId: string, postId: string): Promise<void> {
    await this.prisma.reaction.deleteMany({
      where: { ...postTarget(postId), userId },
    });
    this.realtime.toPost(postId, 'reaction.changed', { userId });
  }

  async listReactions(
    userId: string,
    postId: string,
    q: ListReactionsQuery,
  ): Promise<ReactionPageDto> {
    await this.ensurePost(postId);
    const target = postTarget(postId);
    const limit = q.limit ?? 30;
    const [groups, mine, rows] = await Promise.all([
      this.prisma.reaction.groupBy({
        by: ['kind'],
        where: target,
        _count: { _all: true },
      }),
      this.prisma.reaction.findUnique({
        where: { targetType_targetId_userId: { ...target, userId } },
        select: { kind: true },
      }),
      this.prisma.reaction.findMany({
        where: { ...target, ...(q.kind ? { kind: q.kind } : {}) },
        include: { user: { select: commentAuthorSelect } },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
        ...(q.cursor ? { cursor: { id: q.cursor }, skip: 1 } : {}),
      }),
    ]);
    const page = rows.slice(0, limit);
    const totals = new Map(
      groups.map((group) => [group.kind, group._count._all]),
    );
    return {
      counts: Object.values(ReactionKind).map((kind) => ({
        kind,
        count: totals.get(kind) ?? 0,
      })),
      myKind: mine?.kind,
      items: page.map((row) => ({
        id: row.user.id,
        name: row.user.name,
        avatarUrl: row.user.avatarUrl,
        kind: row.kind,
        reactedAt: row.createdAt,
      })),
      nextCursor: rows.length > limit ? page.at(-1)?.id : undefined,
    };
  }

  private async ensurePost(postId: string): Promise<void> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { id: true },
    });
    if (!post) throw this.notFound('post_not_found', 'Không tìm thấy kèo');
  }

  private toCommentDto(row: {
    id: string;
    postId: string;
    body: string;
    createdAt: Date;
    updatedAt: Date;
    user: { id: string; name: string; avatarUrl: string | null };
  }): CommentDto {
    return {
      id: row.id,
      postId: row.postId,
      body: row.body,
      author: row.user,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }

  private notFound(code: string, message: string) {
    return new AppError(HttpStatus.NOT_FOUND, code, message);
  }
}
