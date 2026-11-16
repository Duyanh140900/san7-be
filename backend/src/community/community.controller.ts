import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import {
  CommentDto,
  CommentPageDto,
  CreateCommentDto,
  CursorPageQuery,
  ListReactionsQuery,
  ReactionPageDto,
  SetReactionDto,
} from './community.dto.js';
import { CommunityService } from './community.service.js';

/** Bình luận và cảm xúc cho kèo. Toàn bộ endpoint yêu cầu người dùng đã đăng nhập. */
@ApiTags('community')
@ApiBearerAuth()
@Controller('posts/:postId')
export class CommunityController {
  constructor(private readonly community: CommunityService) {}

  @Post('comments')
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  @ApiCreatedResponse({ type: CommentDto })
  createComment(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: CreateCommentDto,
  ): Promise<CommentDto> {
    return this.community.createComment(user.userId, postId, dto);
  }

  @Get('comments')
  @ApiOkResponse({ type: CommentPageDto })
  listComments(
    @Param('postId', ParseUUIDPipe) postId: string,
    @Query() q: CursorPageQuery,
  ): Promise<CommentPageDto> {
    return this.community.listComments(postId, q);
  }

  @Delete('comments/:commentId')
  @HttpCode(204)
  @ApiNoContentResponse()
  deleteComment(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Param('commentId', ParseUUIDPipe) commentId: string,
  ): Promise<void> {
    return this.community.deleteComment(user.userId, postId, commentId);
  }

  @Put('reaction')
  @HttpCode(204)
  @ApiNoContentResponse()
  setReaction(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: SetReactionDto,
  ): Promise<void> {
    return this.community.setReaction(user.userId, postId, dto);
  }

  @Delete('reaction')
  @HttpCode(204)
  @ApiNoContentResponse()
  removeReaction(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<void> {
    return this.community.removeReaction(user.userId, postId);
  }

  @Get('reactions')
  @ApiOkResponse({ type: ReactionPageDto })
  listReactions(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Query() q: ListReactionsQuery,
  ): Promise<ReactionPageDto> {
    return this.community.listReactions(user.userId, postId, q);
  }
}
