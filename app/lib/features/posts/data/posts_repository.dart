import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Kèo: Bảng tin, đăng kèo, nhận kèo, xác nhận.
class PostsRepository {
  PostsRepository(this._api, this._dio);
  final San7Api _api;
  final Dio _dio;

  /// `GET /v1/feed`: trang gồm kèo và thẻ kết quả trận (`kind: match_result`), nên đọc
  /// từng phần tử thay vì dùng `FeedPageDto` chỉ có kèo.
  Future<FeedResult> feed({
    PostTypeValue? type,
    String? area,
    String? q,
    String? cursor,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/feed',
      queryParameters: {
        'type': ?type?.value,
        'area': ?area,
        'q': ?((q ?? '').trim().isEmpty ? null : q!.trim()),
        'cursor': ?cursor,
        'limit': 20,
      },
    );
    final data = res.data!;
    final entries = <FeedEntry>[];
    for (final raw in (data['items'] as List).cast<Map<String, dynamic>>()) {
      entries.add(
        raw['kind'] == 'match_result'
            ? MatchResultEntry.fromJson(raw)
            : PostEntry(PostDto.fromJson(raw)),
      );
    }
    return FeedResult(entries, data['nextCursor'] as String?);
  });

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
  (ref) => PostsRepository(ref.watch(apiProvider), ref.watch(dioProvider)),
);

/// Một phần tử Bảng tin: kèo hoặc thẻ kết quả trận.
sealed class FeedEntry {
  const FeedEntry();
}

class PostEntry extends FeedEntry {
  const PostEntry(this.post);
  final PostDto post;
}

class ResultTeam {
  const ResultTeam({
    required this.id,
    required this.name,
    required this.crestColor,
    required this.score,
  });
  factory ResultTeam.fromJson(Map<String, dynamic> j) => ResultTeam(
    id: '${j['id']}',
    name: '${j['name']}',
    crestColor: '${j['crestColor'] ?? '#248A3D'}',
    score: (j['score'] as num?)?.toInt() ?? 0,
  );
  final String id;
  final String name;
  final String crestColor;
  final int score;
}

class MatchResultEntry extends FeedEntry {
  const MatchResultEntry({
    required this.matchId,
    required this.playedAt,
    required this.teamA,
    required this.teamB,
    required this.scorers,
    this.mvpName,
  });
  factory MatchResultEntry.fromJson(Map<String, dynamic> raw) {
    final r = (raw['result'] ?? raw) as Map<String, dynamic>;
    return MatchResultEntry(
      matchId: '${r['matchId']}',
      playedAt: DateTime.parse('${r['playedAt']}'),
      teamA: ResultTeam.fromJson(r['teamA'] as Map<String, dynamic>),
      teamB: ResultTeam.fromJson(r['teamB'] as Map<String, dynamic>),
      scorers: [
        for (final s in (r['scorers'] as List? ?? const []).cast<Map<String, dynamic>>())
          (name: '${s['name']}', goals: (s['goals'] as num?)?.toInt() ?? 1),
      ],
      mvpName: r['mvpName'] as String?,
    );
  }
  final String matchId;
  final DateTime playedAt;
  final ResultTeam teamA;
  final ResultTeam teamB;
  final List<({String name, int goals})> scorers;
  final String? mvpName;
}

class FeedResult {
  const FeedResult(this.items, this.nextCursor);
  final List<FeedEntry> items;
  final String? nextCursor;
}
