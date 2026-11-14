import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Đội và thành viên.
class TeamRepository {
  TeamRepository(this._api);
  final San7Api _api;

  Future<TeamDto> create({
    required String name,
    required String area,
    required TeamLevelValue level,
  }) => apiCall(
    () => _api.teams.teamsCreate(
      body: CreateTeamDto(name: name, area: area, level: TeamLevelKnown(level)),
    ),
  );

  Future<TeamInvitePreviewDto> previewInvite(String code) =>
      apiCall(() => _api.teams.teamsPreviewInvite(code: code));

  Future<MembershipDto> join(String code) =>
      apiCall(() => _api.teams.teamsJoin(body: JoinTeamDto(code: code)));

  Future<TeamDetailDto> detail(String teamId) =>
      apiCall(() => _api.teams.teamDetailDetail(teamId: teamId));

  Future<TeamDetailDto> update(String teamId, UpdateTeamDto body) =>
      apiCall(() => _api.teams.teamDetailUpdate(teamId: teamId, body: body));

  Future<InviteDto> regenerateInvite(String teamId) =>
      apiCall(() => _api.teams.teamDetailRegenerateInvite(teamId: teamId));

  Future<MemberListDto> members(String teamId) =>
      apiCall(() => _api.members.membersList(teamId: teamId));

  Future<void> approve(String teamId, String userId) =>
      apiCall(() => _api.members.membersApprove(teamId: teamId, userId: userId));

  Future<void> reject(String teamId, String userId) =>
      apiCall(() => _api.members.membersReject(teamId: teamId, userId: userId));

  Future<void> changeRole(String teamId, String userId, TeamRoleValue role) => apiCall(
    () => _api.members.membersChangeRole(
      teamId: teamId,
      userId: userId,
      body: ChangeRoleDto(role: TeamRoleKnown(role)),
    ),
  );

  Future<void> remove(String teamId, String userId) =>
      apiCall(() => _api.members.membersRemove(teamId: teamId, userId: userId));

  Future<void> leave(String teamId) => apiCall(() => _api.members.membersLeave(teamId: teamId));
}

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => TeamRepository(ref.watch(apiProvider)),
);
