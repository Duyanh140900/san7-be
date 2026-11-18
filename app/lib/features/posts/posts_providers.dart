import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import '../../core/auth/auth_controller.dart';
import 'data/posts_repository.dart';

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => const FeedFilter();

  void setType(PostTypeValue? type) => state = state.withBasic(type: () => type);
  void setArea(String? area) => state = state.withBasic(area: () => area);
  void setQuery(String q) => state = state.withBasic(q: q);

  /// Áp bộ lọc từ màn 30 (giữ từ khoá đang gõ).
  void apply(FeedFilter f) => state = f.withBasic(q: state.q);
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(
  FeedFilterNotifier.new,
);

class FeedState {
  const FeedState({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.total = 0,
  });
  final List<FeedEntry> items;
  final String? nextCursor;
  final bool loadingMore;

  /// Tổng kèo phù hợp bộ lọc
  final int total;

  FeedState copyWith({
    List<FeedEntry>? items,
    String? nextCursor,
    bool? loadingMore,
  }) => FeedState(
    items: items ?? this.items,
    nextCursor: nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
    total: total,
  );
}

/// Bảng tin phân trang cursor: trang đầu khi đổi bộ lọc, [loadMore] khi cuộn tới cuối.
class FeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final f = ref.watch(feedFilterProvider);
    final page = await ref.read(postsRepositoryProvider).feed(f);
    return FeedState(items: page.items, nextCursor: page.nextCursor, total: page.total);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.nextCursor == null || cur.loadingMore) return;
    state = AsyncData(
      cur.copyWith(loadingMore: true, nextCursor: cur.nextCursor),
    );
    final f = ref.read(feedFilterProvider);
    try {
      final page = await ref.read(postsRepositoryProvider).feed(f, cursor: cur.nextCursor);
      state = AsyncData(
        FeedState(
          items: [...cur.items, ...page.items],
          nextCursor: page.nextCursor,
          total: page.total,
        ),
      );
    } catch (_) {
      state = AsyncData(
        cur.copyWith(loadingMore: false, nextCursor: cur.nextCursor),
      );
    }
  }
}

/// Số kèo phù hợp một bộ lọc nháp (nút "Xem N kèo phù hợp" ở màn 30).
final feedCountProvider = FutureProvider.autoDispose.family<int, FeedFilter>(
  (ref, f) async => (await ref.watch(postsRepositoryProvider).feed(f, limit: 1)).total,
);

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

final postDetailProvider = FutureProvider.autoDispose
    .family<PostDetailDto, String>(
      (ref, postId) => ref.watch(postsRepositoryProvider).detail(postId),
    );

/// Tổng hợp năm cảm xúc và cảm xúc của người đang đăng nhập cho một kèo.
final postReactionsProvider = FutureProvider.autoDispose
    .family<ReactionPageDto, String>(
      (ref, postId) => ref.watch(postsRepositoryProvider).reactions(postId),
    );

typedef PostKey = ({String teamId, String postId});

final postRequestsProvider = FutureProvider.autoDispose
    .family<List<MatchRequestDto>, PostKey>(
      (ref, k) =>
          ref.watch(postsRepositoryProvider).requests(k.teamId, k.postId),
    );

typedef RequestKey = ({String teamId, String requestId});

final requestDetailProvider = FutureProvider.autoDispose
    .family<RequestDetailDto, RequestKey>(
      (ref, k) => ref
          .watch(postsRepositoryProvider)
          .requestDetail(k.teamId, k.requestId),
    );

/// Các đội tôi là đội trưởng/phó (được đăng kèo, nhận kèo).
final managedTeamsProvider = Provider<List<MyTeamDto>>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthSignedIn) return const [];
  return [
    for (final t in auth.me.teams)
      if (t.status == MemberStatus.active &&
          (t.role == TeamRole.captain || t.role == TeamRole.vice))
        t,
  ];
});

extension RequestStatusX on RequestStatus {
  bool get isPending => this == RequestStatus.pending;
}

extension PostStatusX on PostStatus {
  bool get isOpen => this == PostStatus.open;
}
