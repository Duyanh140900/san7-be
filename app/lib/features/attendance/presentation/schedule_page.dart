import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../team/presentation/team_page_scaffold.dart';
import '../../team/team_providers.dart';
import '../data/events_repository.dart';
import 'event_widgets.dart';

/// Tab Đội · Lịch & điểm danh (màn 18): lịch gần nhất + điểm danh, danh sách sắp tới.
class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const SizedBox.shrink();
    final team = ref.watch(teamDetailProvider(teamId));
    final events = ref.watch(upcomingEventsProvider(teamId));
    final canCreate = team.value?.myRole.canManageEvents ?? false;

    return TeamPageScaffold(
      section: TeamSection.schedule,
      onRefresh: () async {
        ref.invalidate(upcomingEventsProvider(teamId));
        ref.invalidate(eventDetailProvider);
        await ref.read(upcomingEventsProvider(teamId).future);
      },
      header: Row(
        children: [
          Expanded(child: Text('Lịch đội', style: Theme.of(context).textTheme.displaySmall)),
          if (canCreate)
            LinkButton('+ Tạo lịch', onTap: () => context.push(Routes.teamEventNew))
          else if (team.value != null)
            Text(
              team.value!.name,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
        ],
      ),
      children: [
        AsyncView(
          value: events,
          onRetry: () => ref.invalidate(upcomingEventsProvider(teamId)),
          data: (list) {
            if (list.isEmpty) {
              return AppCard(
                child: Text(
                  canCreate
                      ? 'Chưa có lịch nào. Bấm “+ Tạo lịch” để tạo trận hoặc buổi đá nội bộ.'
                      : 'Chưa có lịch nào sắp tới.',
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              );
            }
            final next = list.first;
            return Column(
              children: [
                EventMainCard(teamId: teamId, event: EventView.summary(next)),
                const SizedBox(height: 14),
                EventAttendeesCard(teamId: teamId, eventId: next.id),
                if (list.length > 1) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardHeader('Sắp tới'),
                        const SizedBox(height: 4),
                        for (final (i, e) in list.skip(1).indexed) ...[
                          if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          EventRow(event: e, onTap: () => context.push(Routes.teamEvent(e.id))),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Thẻ "Điểm danh": danh sách từng thành viên và câu trả lời.
class EventAttendeesCard extends ConsumerWidget {
  const EventAttendeesCard({super.key, required this.teamId, required this.eventId});
  final String teamId;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (teamId: teamId, eventId: eventId);
    final detail = ref.watch(eventDetailProvider(key));
    final auth = ref.watch(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: AsyncView<EventDetailDto>(
        value: detail,
        onRetry: () => ref.invalidate(eventDetailProvider(key)),
        data: (d) {
          final pending = d.counts.pending;
          return Column(
            children: [
              CardHeader(
                'Điểm danh',
                trailing: pending > 0
                    ? LinkButton(
                        'Nhắc $pending người',
                        onTap: () => showToast(
                          context,
                          'Nhắc qua thông báo đẩy sẽ có ở bản sau. Tạm thời nhắn nhóm giúp nhé.',
                        ),
                      )
                    : null,
              ),
              for (final (i, a) in d.attendees.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                AttendeeRow(attendee: a, isMe: a.userId == myId),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Chi tiết một lịch (mở từ "Sắp tới" hoặc thẻ "Trận tới").
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const Scaffold();
    final key = (teamId: teamId, eventId: eventId);
    final detail = ref.watch(eventDetailProvider(key));
    final canManage = ref.watch(teamDetailProvider(teamId)).value?.myRole.canManageEvents ?? false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Chi tiết lịch',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (canManage)
            TextButton(
              onPressed: () => _delete(context, ref, teamId),
              child: const Text('Xoá', style: TextStyle(color: AppColors.red)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eventDetailProvider(key));
          await ref.read(eventDetailProvider(key).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            AsyncView<EventDetailDto>(
              value: detail,
              onRetry: () => ref.invalidate(eventDetailProvider(key)),
              data: (d) => EventMainCard(teamId: teamId, event: EventView.detail(d)),
            ),
            const SizedBox(height: 14),
            EventAttendeesCard(teamId: teamId, eventId: eventId),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String teamId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá lịch này?'),
        content: const Text('Điểm danh của lịch cũng bị xoá.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await runAction(
      context,
      () => ref.read(eventsRepositoryProvider).remove(teamId, eventId),
      success: 'Đã xoá lịch',
    );
    if (done && context.mounted) {
      ref.invalidate(upcomingEventsProvider(teamId));
      context.pop();
    }
  }
}
