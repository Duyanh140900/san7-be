import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Tìm kiếm chung: đội, sân, kèo, cầu thủ (GET /v1/search, /v1/search/trending).
class SearchRepository {
  SearchRepository(this._api);
  final San7Api _api;

  Future<SearchResponseDto> find(String q, {SearchFindType? type}) =>
      apiCall(() => _api.search.searchFind(q: q, type: type));

  Future<List<TrendingSearchDto>> trending() => apiCall(() => _api.search.searchTrending());
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(apiProvider)),
);

typedef SearchKey = ({String q, SearchFindTypeValue type});

final searchResultsProvider = FutureProvider.autoDispose.family<SearchResponseDto, SearchKey>(
  (ref, k) => ref
      .watch(searchRepositoryProvider)
      .find(k.q, type: k.type == SearchFindTypeValue.all ? null : SearchFindTypeKnown(k.type)),
);

final trendingSearchProvider = FutureProvider.autoDispose<List<TrendingSearchDto>>(
  (ref) => ref.watch(searchRepositoryProvider).trending(),
);

/// Tìm gần đây, giữ trong bộ nhớ phiên (chưa lưu máy).
class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    state = [t, ...state.where((e) => e != t)].take(6).toList();
  }

  void clear() => state = const [];
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
