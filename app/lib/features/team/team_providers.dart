import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import '../../core/auth/auth_controller.dart';
import '../attendance/data/events_repository.dart';
import '../funds/data/funds_repository.dart';
import 'data/team_repository.dart';

/// Đội đang xem: đội active đầu tiên của tôi (null nếu chưa có hoặc đang chờ duyệt).
final currentTeamIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth is! AuthSignedIn) return null;
  for (final t in auth.me.teams) {
    if (t.status case MemberStatusKnown(value: MemberStatusValue.active)) return t.teamId;
  }
  return null;
});

final teamDetailProvider = FutureProvider.autoDispose.family<TeamDetailDto, String>(
  (ref, teamId) => ref.watch(teamRepositoryProvider).detail(teamId),
);

final teamPublicProfileProvider = FutureProvider.autoDispose.family<TeamPublicProfileDto, String>(
  (ref, teamId) => ref.watch(teamRepositoryProvider).publicProfile(teamId),
);

final membersProvider = FutureProvider.autoDispose.family<MemberListDto, String>(
  (ref, teamId) => ref.watch(teamRepositoryProvider).members(teamId),
);

final upcomingEventsProvider = FutureProvider.autoDispose.family<List<EventSummaryDto>, String>(
  (ref, teamId) => ref.watch(eventsRepositoryProvider).upcoming(teamId),
);

typedef EventKey = ({String teamId, String eventId});

final eventDetailProvider = FutureProvider.autoDispose.family<EventDetailDto, EventKey>(
  (ref, k) => ref.watch(eventsRepositoryProvider).detail(k.teamId, k.eventId),
);

final fundSummaryProvider = FutureProvider.autoDispose.family<FundSummaryDto, String>(
  (ref, teamId) => ref.watch(fundsRepositoryProvider).summary(teamId),
);

final fineRulesProvider = FutureProvider.autoDispose.family<List<FineRuleDto>, String>(
  (ref, teamId) => ref.watch(fundsRepositoryProvider).fineRules(teamId),
);
final joinRequestsProvider = FutureProvider.autoDispose.family<List<TeamMemberDto>, String>(
  (ref, teamId) => ref.watch(teamRepositoryProvider).joinRequests(teamId),
);

/// Quyền theo vai trò (khớp với guard phía backend).
extension TeamRolePermissions on TeamRole {
  TeamRoleValue? get _v => switch (this) {
    TeamRoleKnown(:final value) => value,
    _ => null,
  };
  bool get isCaptain => _v == TeamRoleValue.captain;
  bool get canManageMembers => _v == TeamRoleValue.captain || _v == TeamRoleValue.vice;
  bool get canManageEvents => canManageMembers;
  bool get canManageFunds => _v == TeamRoleValue.captain || _v == TeamRoleValue.treasurer;
}
