import {
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiExtraModels,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser, type AuthUser } from '../common/auth.decorators.js';
import {
  CurrentMember,
  TeamRoles,
  TeamScoped,
  type TeamMembership,
} from '../common/team-member.guard.js';
import {
  AcceptResultDto,
  CreatePostApplicationDto,
  CreatePostDto,
  FeedPageDto,
  FeedMatchResultItemDto,
  FeedQuery,
  MatchRequestDto,
  MyPostsQuery,
  MyRequestDto,
  PostDetailDto,
  PostApplicationDto,
  PostDto,
  RequestDetailDto,
  SendRequestDto,
  UpdatePostApplicationDto,
} from './posts.dto.js';
import { ApplicationsService } from './applications.service.js';
import { PostsService } from './posts.service.js';
import { RequestsService } from './requests.service.js';

/** Bảng tin và chi tiết kèo: mọi người đã đăng nhập đều xem được. */
@ApiTags('posts')
@ApiBearerAuth()
@ApiExtraModels(FeedMatchResultItemDto)
@Controller()
export class PostsController {
  constructor(
    private readonly posts: PostsService,
    private readonly applications: ApplicationsService,
  ) {}

  @Get('feed')
  @ApiOkResponse({ type: FeedPageDto })
  feed(
    @CurrentUser() user: AuthUser,
    @Query() q: FeedQuery,
  ): Promise<FeedPageDto> {
    return this.posts.feed(user.userId, q);
  }

  @Get('posts/:postId')
  @ApiOkResponse({ type: PostDetailDto })
  detail(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<PostDetailDto> {
    return this.posts.detail(user.userId, postId);
  }

  @Post('posts/:postId/applications')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiCreatedResponse({ type: PostApplicationDto })
  apply(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: CreatePostApplicationDto,
  ): Promise<PostApplicationDto> {
    return this.applications.create(user.userId, postId, dto);
  }

  @Get('posts/:postId/applications')
  @ApiOkResponse({ type: [PostApplicationDto] })
  listApplications(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<PostApplicationDto[]> {
    return this.applications.list(user.userId, postId);
  }

  @Patch('posts/:postId/applications/:applicationId')
  @ApiOkResponse({ type: PostApplicationDto })
  updateApplication(
    @CurrentUser() user: AuthUser,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Param('applicationId', ParseUUIDPipe) applicationId: string,
    @Body() dto: UpdatePostApplicationDto,
  ): Promise<PostApplicationDto> {
    return this.applications.update(user.userId, postId, applicationId, dto);
  }

  @Get('me/posts')
  @ApiOkResponse({ type: FeedPageDto })
  myPosts(@CurrentUser() user: AuthUser, @Query() q: MyPostsQuery): Promise<FeedPageDto> {
    return this.posts.myPosts(user.userId, q);
  }
}

/**
 * Thao tác của đội với kèo. :teamId là đội đang hành động:
 * đội đăng kèo (đăng, đóng, xem yêu cầu, chấp nhận, từ chối) hoặc đội nhận kèo (gửi, huỷ).
 */
@ApiTags('posts')
@TeamScoped()
@Controller('teams/:teamId')
export class TeamPostsController {
  constructor(
    private readonly posts: PostsService,
    private readonly requests: RequestsService,
  ) {}

  @Post('posts')
  @TeamRoles('captain', 'vice')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @ApiCreatedResponse({ type: PostDto })
  create(
    @CurrentMember() me: TeamMembership,
    @Body() dto: CreatePostDto,
  ): Promise<PostDto> {
    return this.posts.create(me, dto);
  }

  @Post('posts/:postId/close')
  @TeamRoles('captain', 'vice')
  @HttpCode(204)
  @ApiNoContentResponse()
  close(
    @CurrentMember() me: TeamMembership,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<void> {
    return this.posts.close(me, postId);
  }

  @Get('posts/:postId/requests')
  @ApiOkResponse({ type: [MatchRequestDto] })
  listRequests(
    @CurrentMember() me: TeamMembership,
    @Param('postId', ParseUUIDPipe) postId: string,
  ): Promise<MatchRequestDto[]> {
    return this.requests.listForPost(me, postId);
  }

  @Post('posts/:postId/requests')
  @TeamRoles('captain', 'vice')
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  @ApiCreatedResponse({ type: MyRequestDto })
  sendRequest(
    @CurrentMember() me: TeamMembership,
    @Param('postId', ParseUUIDPipe) postId: string,
    @Body() dto: SendRequestDto,
  ): Promise<MyRequestDto> {
    return this.requests.send(me, postId, dto);
  }

  @Get('requests/:requestId')
  @ApiOkResponse({ type: RequestDetailDto })
  requestDetail(
    @CurrentMember() me: TeamMembership,
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ): Promise<RequestDetailDto> {
    return this.requests.detail(me, requestId);
  }

  @Post('requests/:requestId/accept')
  @TeamRoles('captain', 'vice')
  @HttpCode(200)
  @ApiOkResponse({ type: AcceptResultDto })
  accept(
    @CurrentMember() me: TeamMembership,
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ): Promise<AcceptResultDto> {
    return this.requests.accept(me, requestId);
  }

  @Post('requests/:requestId/decline')
  @TeamRoles('captain', 'vice')
  @HttpCode(204)
  @ApiNoContentResponse()
  decline(
    @CurrentMember() me: TeamMembership,
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ): Promise<void> {
    return this.requests.decline(me, requestId);
  }

  @Post('requests/:requestId/cancel')
  @TeamRoles('captain', 'vice')
  @HttpCode(204)
  @ApiNoContentResponse()
  cancel(
    @CurrentMember() me: TeamMembership,
    @Param('requestId', ParseUUIDPipe) requestId: string,
  ): Promise<void> {
    return this.requests.cancel(me, requestId);
  }
}
