import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import '../../core/auth/auth_controller.dart';
import 'data/posts_repository.dart';

/// Bộ lọc Bảng tin: loại kèo + khu vực (null = tất cả).
typedef FeedFilter = ({PostTypeValue? type, String? area});

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => (type: null, area: null);

  void setType(PostTypeValue? type) => state = (type: type, area: state.area);
  void setArea(String? area) => state = (type: state.type, area: area);
}

final feedFilterProvider = NotifierProvider<FeedFilterNotifier, FeedFilter>(FeedFilterNotifier.new);

class FeedState {
  const FeedState({required this.items, this.nextCursor, this.loadingMore = false});
  final List<PostDto> items;
  final String? nextCursor;
  final bool loadingMore;

  FeedState copyWith({List<PostDto>? items, String? nextCursor, bool? loadingMore}) => FeedState(
    items: items ?? this.items,
    nextCursor: nextCursor,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Bảng tin phân trang cursor: trang đầu khi đổi bộ lọc, [loadMore] khi cuộn tới cuối.
class FeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final f = ref.watch(feedFilterProvider);
    final page = await ref.read(postsRepositoryProvider).feed(type: f.type, area: f.area);
    return FeedState(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || cur.nextCursor == null || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, nextCursor: cur.nextCursor));
    final f = ref.read(feedFilterProvider);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .feed(type: f.type, area: f.area, cursor: cur.nextCursor);
      state = AsyncData(
        FeedState(items: [...cur.items, ...page.items], nextCursor: page.nextCursor),
      );
    } catch (_) {
      state = AsyncData(cur.copyWith(loadingMore: false, nextCursor: cur.nextCursor));
    }
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(FeedNotifier.new);

final postDetailProvider = FutureProvider.autoDispose.family<PostDetailDto, String>(
  (ref, postId) => ref.watch(postsRepositoryProvider).detail(postId),
);

typedef PostKey = ({String teamId, String postId});

final postRequestsProvider = FutureProvider.autoDispose.family<List<MatchRequestDto>, PostKey>(
  (ref, k) => ref.watch(postsRepositoryProvider).requests(k.teamId, k.postId),
);

typedef RequestKey = ({String teamId, String requestId});

final requestDetailProvider = FutureProvider.autoDispose.family<RequestDetailDto, RequestKey>(
  (ref, k) => ref.watch(postsRepositoryProvider).requestDetail(k.teamId, k.requestId),
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
