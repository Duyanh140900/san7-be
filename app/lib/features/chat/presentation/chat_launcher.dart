import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_error.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../matches/matches_providers.dart';
import '../../posts/posts_providers.dart';
import '../../team/team_providers.dart';

const _noChat = 'Chưa có trận đã chốt để nhắn tin';

/// Mở màn 21 từ một lịch (event) đã gắn trận.
Future<void> openChatForEvent(
  BuildContext context,
  WidgetRef ref, {
  required String teamId,
  required String? eventId,
}) async {
  try {
    if (eventId == null) return showToast(context, _noChat, type: ToastType.warning);
    final e = await ref.read(eventDetailProvider((teamId: teamId, eventId: eventId)).future);
    if (!context.mounted) return;
    final matchId = e.matchId;
    if (matchId == null) return showToast(context, _noChat, type: ToastType.warning);
    context.push(Routes.chat(teamId, matchId));
  } catch (e) {
    if (context.mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
  }
}

/// Mở màn 21 từ một yêu cầu nhận kèo (cần đã được chấp nhận để có trận).
Future<void> openChatForRequest(
  BuildContext context,
  WidgetRef ref, {
  required String teamId,
  required String requestId,
}) async {
  try {
    final d = await ref.read(requestDetailProvider((teamId: teamId, requestId: requestId)).future);
    if (!context.mounted) return;
    await openChatForEvent(context, ref, teamId: teamId, eventId: d.eventId);
  } catch (e) {
    if (context.mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
  }
}

/// Mở màn 21 với [otherTeamId]: tìm trận đã chốt sắp tới giữa đội đang chọn và đội đó.
Future<void> openChatWithTeam(BuildContext context, WidgetRef ref, String otherTeamId) async {
  final teamId = ref.read(currentTeamIdProvider);
  if (teamId == null) return showToast(context, _noChat, type: ToastType.warning);
  try {
    final events = await ref.read(upcomingEventsProvider(teamId).future);
    for (final ev in events) {
      final matchId = ev.matchId;
      if (matchId == null) continue;
      final m = await ref.read(matchDetailProvider((teamId: teamId, matchId: matchId)).future);
      final opp = m.homeTeam.id == m.myTeamId ? m.awayTeam : m.homeTeam;
      if (opp.id == otherTeamId) {
        if (context.mounted) context.push(Routes.chat(teamId, matchId));
        return;
      }
    }
    if (context.mounted) showToast(context, _noChat, type: ToastType.warning);
  } catch (e) {
    if (context.mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
  }
}
