import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';

class TeamRepository {
  TeamRepository(this._api);
  final San7Api _api;

  Future<TeamDto> create({
    required String name,
    required String area,
    required TeamLevelValue level,
  }) async {
    try {
      return await _api.teams.teamsCreate(
        body: CreateTeamDto(name: name, area: area, level: TeamLevelKnown(level)),
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<TeamInvitePreviewDto> previewInvite(String code) async {
    try {
      return await _api.teams.teamsPreviewInvite(code: code);
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<MembershipDto> join(String code) async {
    try {
      return await _api.teams.teamsJoin(body: JoinTeamDto(code: code));
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(apiProvider)),
);
