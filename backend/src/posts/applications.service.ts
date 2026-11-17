import { HttpStatus, Injectable } from '@nestjs/common';
import { AppError } from '../common/errors.js';
import { Prisma } from '../generated/prisma/client.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type {
  CreatePostApplicationDto,
  PostApplicationDto,
  UpdatePostApplicationDto,
} from './posts.dto.js';

const managerWhere = (userId: string) => ({
  userId,
  status: 'active' as const,
  role: { in: ['captain', 'vice'] as Array<'captain' | 'vice'> },
});

@Injectable()
export class ApplicationsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(
    userId: string,
    postId: string,
    dto: CreatePostApplicationDto,
  ): Promise<PostApplicationDto> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { type: true, status: true },
    });
    if (!post) throw this.postNotFound();
    if (post.type !== 'recruit' || post.status !== 'open') {
      throw new AppError(
        HttpStatus.CONFLICT,
        'post_not_open_for_applications',
        'Kèo này không nhận ứng tuyển',
      );
    }
    try {
      const application = await this.prisma.postApplication.create({
        data: { postId, userId, position: dto.position, note: dto.note || null },
        include: { user: { select: { id: true, name: true } } },
      });
      return application;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new AppError(
          HttpStatus.CONFLICT,
          'already_applied',
          'Bạn đã ứng tuyển kèo này',
        );
      }
      throw error;
    }
  }

  async list(userId: string, postId: string): Promise<PostApplicationDto[]> {
    await this.assertManager(userId, postId);
    return this.prisma.postApplication.findMany({
      where: { postId },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: { id: true, name: true } } },
    });
  }

  async update(
    userId: string,
    postId: string,
    applicationId: string,
    dto: UpdatePostApplicationDto,
  ): Promise<PostApplicationDto> {
    await this.assertManager(userId, postId);
    const application = await this.prisma.postApplication.findFirst({
      where: { id: applicationId, postId },
      select: { id: true },
    });
    if (!application) throw this.applicationNotFound();
    return this.prisma.postApplication.update({
      where: { id: application.id },
      data: { status: dto.status },
      include: { user: { select: { id: true, name: true } } },
    });
  }

  private async assertManager(userId: string, postId: string): Promise<void> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      select: { teamId: true },
    });
    if (!post) throw this.postNotFound();
    const manager = await this.prisma.teamMember.findFirst({
      where: { teamId: post.teamId, ...managerWhere(userId) },
      select: { id: true },
    });
    if (!manager) throw this.postNotFound();
  }

  private postNotFound() {
    return new AppError(HttpStatus.NOT_FOUND, 'post_not_found', 'Không tìm thấy kèo');
  }

  private applicationNotFound() {
    return new AppError(
      HttpStatus.NOT_FOUND,
      'application_not_found',
      'Không tìm thấy đơn ứng tuyển',
    );
  }
}
