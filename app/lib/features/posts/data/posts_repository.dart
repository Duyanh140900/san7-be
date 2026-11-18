import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Kèo: Bảng tin, đăng kèo, nhận kèo, xác nhận.
class PostsRepository {
  PostsRepository(this._api);
  final San7Api _api;

  /// `GET /v1/feed`: trang gồm kèo và thẻ kết quả trận (`kind: match_result`), kèm tổng kèo theo bộ lọc.
  Future<FeedResult> feed(FeedFilter f, {String? cursor, int limit = 20}) => apiCall(() async {
    final q = f.q.trim();
    final page = await _api.posts.postsFeed(
      type: f.type == null ? null : PostTypeKnown(f.type!),
      area: f.area,
      q: q.isEmpty ? null : q,
      date: f.date,
      timeSlot: f.timeSlot == null ? null : PostsFeedTimeSlotKnown(f.timeSlot!),
      levelMin: f.levelMin == null ? null : TeamLevelKnown(f.levelMin!),
      levelMax: f.levelMax == null ? null : TeamLevelKnown(f.levelMax!),
      ratioType: f.ratioType == null ? null : PostDealKnown(f.ratioType!),
      minRating: f.minRating,
      hideCancellers: f.hideCancellers ? true : null,
      cursor: cursor,
      limit: limit,
    );
    return FeedResult([
      for (final i in page.items)
        switch (i) {
          PostDto() => PostEntry(i),
          FeedMatchResultItemDto(:final result) => MatchResultEntry(result),
        },
    ], page.nextCursor, page.total);
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
  const FeedResult(this.items, this.nextCursor, this.total);
  final List<FeedEntry> items;
  final String? nextCursor;

  /// Tổng kèo phù hợp bộ lọc (trước phân trang).
  final int total;
}

/// Bộ lọc Bảng tin (màn 1 và màn 30). Null / false = không lọc.
class FeedFilter {
  const FeedFilter({
    this.type,
    this.area,
    this.q = '',
    this.maxKm,
    this.date,
    this.timeSlot,
    this.levelMin,
    this.levelMax,
    this.ratioType,
    this.minRating,
    this.hideCancellers = false,
  });
  final PostTypeValue? type;
  final String? area;
  final String q;
  final num? maxKm;

  /// Ngày đá "yyyy-MM-dd" theo giờ Việt Nam.
  final String? date;
  final PostsFeedTimeSlotValue? timeSlot;
  final TeamLevelValue? levelMin;
  final TeamLevelValue? levelMax;
  final PostDealValue? ratioType;
  final num? minRating;
  final bool hideCancellers;

  /// Số bộ lọc nâng cao đang bật (không tính loại bài, khu vực, từ khoá).
  int get advancedCount => [
    maxKm != null,
    date != null,
    timeSlot != null,
    levelMin != null || levelMax != null,
    ratioType != null,
    minRating != null,
    hideCancellers,
  ].where((e) => e).length;

  /// Giữ loại bài, khu vực, từ khoá; xoá bộ lọc nâng cao.
  FeedFilter clearAdvanced() => FeedFilter(type: type, area: area, q: q);

  FeedFilter withBasic({PostTypeValue? Function()? type, String? Function()? area, String? q}) =>
      FeedFilter(
        type: type != null ? type() : this.type,
        area: area != null ? area() : this.area,
        q: q ?? this.q,
        maxKm: maxKm,
        date: date,
        timeSlot: timeSlot,
        levelMin: levelMin,
        levelMax: levelMax,
        ratioType: ratioType,
        minRating: minRating,
        hideCancellers: hideCancellers,
      );

  @override
  bool operator ==(Object other) =>
      other is FeedFilter &&
      other.type == type &&
      other.area == area &&
      other.q == q &&
      other.maxKm == maxKm &&
      other.date == date &&
      other.timeSlot == timeSlot &&
      other.levelMin == levelMin &&
      other.levelMax == levelMax &&
      other.ratioType == ratioType &&
      other.minRating == minRating &&
      other.hideCancellers == hideCancellers;

  @override
  int get hashCode => Object.hash(
    type, area, q, maxKm, date, timeSlot, levelMin, levelMax, ratioType, minRating, hideCancellers,
  );
}
