import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Sau trận: kết quả, thống kê, đánh giá; hồ sơ đội, bảng vàng, sổ phạt.
class MatchesRepository {
  MatchesRepository(this._api);
  final San7Api _api;

  Future<MatchDetailDto> detail(String teamId, String matchId) =>
      apiCall(() => _api.matches.matchesDetail(teamId: teamId, matchId: matchId));

  Future<MatchDetailDto> setResult(String teamId, String matchId, int home, int away) => apiCall(
    () => _api.matches.matchesSetResult(
      teamId: teamId,
      matchId: matchId,
      body: SetResultDto(homeScore: home, awayScore: away),
    ),
  );

  Future<MatchDetailDto> confirm(String teamId, String matchId) =>
      apiCall(() => _api.matches.matchesConfirm(teamId: teamId, matchId: matchId));

  Future<MatchDetailDto> setStats(
    String teamId,
    String matchId, {
    required List<PlayerStatInput> players,
    String? mvpUserId,
  }) => apiCall(
    () => _api.matches.matchesSetStats(
      teamId: teamId,
      matchId: matchId,
      body: SetStatsDto(players: players, mvpUserId: mvpUserId),
    ),
  );

  Future<MatchDetailDto> review(String teamId, String matchId, SubmitReviewDto body) =>
      apiCall(() => _api.matches.matchesReview(teamId: teamId, matchId: matchId, body: body));

  Future<TeamProfileDto> profile(String teamId) =>
      apiCall(() => _api.matches.teamProfileGet(teamId: teamId));

  Future<HonorsDto> honors({String? month, String? teamId}) =>
      apiCall(() => _api.matches.honorsGet(month: month, teamId: teamId));

  Future<FinesDto> fines(String teamId, {String? period}) =>
      apiCall(() => _api.funds.fundsFines(teamId: teamId, period: period));
}

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => MatchesRepository(ref.watch(apiProvider)),
);
