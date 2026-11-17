import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Kèo: Bảng tin, đăng kèo, nhận kèo, xác nhận.
class PostsRepository {
  PostsRepository(this._api);
  final San7Api _api;

  /// `GET /v1/feed`: trang gồm kèo và thẻ kết quả trận (`kind: match_result`).
  Future<FeedResult> feed({PostTypeValue? type, String? area, String? q, String? cursor}) =>
      apiCall(() async {
        final page = await _api.posts.postsFeed(
          type: type == null ? null : PostTypeKnown(type),
          area: area,
          q: (q ?? '').trim().isEmpty ? null : q!.trim(),
          cursor: cursor,
          limit: 20,
        );
        return FeedResult([
          for (final i in page.items)
            switch (i) {
              PostDto() => PostEntry(i),
              FeedMatchResultItemDto(:final result) => MatchResultEntry(result),
            },
        ], page.nextCursor);
      });

  /// Ứng tuyển kèo tuyển người (409 nếu đã ứng tuyển).
  Future<PostApplicationDto> apply(String postId, {Position? position, String? note}) {
    final text = (note ?? '').trim();
    return apiCall(
      () => _api.posts.postsApply(
        postId: postId,
        body: CreatePostApplicationDto(position: position, note: text.isEmpty ? null : text),
      ),
    );
  }

  /// Danh sách ứng viên (đội trưởng/phó).
  Future<List<PostApplicationDto>> applications(String postId) =>
      apiCall(() => _api.posts.postsListApplications(postId: postId));

  Future<PostApplicationDto> reviewApplication(
    String postId,
    String appId,
    UpdatePostApplicationDtoStatus status,
  ) => apiCall(
    () => _api.posts.postsUpdateApplication(
      postId: postId,
      applicationId: appId,
      body: UpdatePostApplicationDto(status: status),
    ),
  );

  Future<PostDetailDto> detail(String postId) =>
      apiCall(() => _api.posts.postsDetail(postId: postId));

  Future<PostDto> create(String teamId, CreatePostDto body) =>
      apiCall(() => _api.posts.teamPostsCreate(teamId: teamId, body: body));

  Future<void> close(String teamId, String postId) =>
      apiCall(() => _api.posts.teamPostsClose(teamId: teamId, postId: postId));

  Future<List<MatchRequestDto>> requests(String teamId, String postId) =>
      apiCall(
        () => _api.posts.teamPostsListRequests(teamId: teamId, postId: postId),
      );

  Future<MyRequestDto> send(
    String teamId,
    String postId,
    SendRequestDto body,
  ) => apiCall(
    () => _api.posts.teamPostsSendRequest(
      teamId: teamId,
      postId: postId,
      body: body,
    ),
  );

  Future<RequestDetailDto> requestDetail(String teamId, String requestId) =>
      apiCall(
        () => _api.posts.teamPostsRequestDetail(
          teamId: teamId,
          requestId: requestId,
        ),
      );

  Future<AcceptResultDto> accept(String teamId, String requestId) => apiCall(
    () => _api.posts.teamPostsAccept(teamId: teamId, requestId: requestId),
  );

  Future<void> decline(String teamId, String requestId) => apiCall(
    () => _api.posts.teamPostsDecline(teamId: teamId, requestId: requestId),
  );

  Future<void> cancel(String teamId, String requestId) => apiCall(
    () => _api.posts.teamPostsCancel(teamId: teamId, requestId: requestId),
  );

  Future<CommentPageDto> comments(String postId, {String? cursor}) => apiCall(
    () => _api.community.communityListComments(
      postId: postId,
      cursor: cursor,
      limit: 30,
    ),
  );

  Future<CommentDto> addComment(String postId, String body) => apiCall(
    () => _api.community.communityCreateComment(
      postId: postId,
      body: CreateCommentDto(body: body),
    ),
  );

  Future<void> deleteComment(String postId, String commentId) => apiCall(
    () => _api.community.communityDeleteComment(
      postId: postId,
      commentId: commentId,
    ),
  );

  Future<ReactionPageDto> reactions(
    String postId, {
    String? cursor,
    ReactionKind? kind,
  }) => apiCall(
    () => _api.community.communityListReactions(
      postId: postId,
      cursor: cursor,
      kind: kind,
      limit: 30,
    ),
  );

  Future<void> setReaction(String postId, ReactionKind kind) => apiCall(
    () => _api.community.communitySetReaction(
      postId: postId,
      body: SetReactionDto(kind: kind),
    ),
  );

  Future<void> removeReaction(String postId) =>
      apiCall(() => _api.community.communityRemoveReaction(postId: postId));
}

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepository(ref.watch(apiProvider)),
);

/// Một phần tử Bảng tin: kèo hoặc thẻ kết quả trận.
sealed class FeedEntry {
  const FeedEntry();
}

class PostEntry extends FeedEntry {
  const PostEntry(this.post);
  final PostDto post;
}

class MatchResultEntry extends FeedEntry {
  const MatchResultEntry(this.result);
  final FeedMatchResultDto result;
}

class FeedResult {
  const FeedResult(this.items, this.nextCursor);
  final List<FeedEntry> items;
  final String? nextCursor;
}
