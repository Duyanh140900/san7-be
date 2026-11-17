import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../posts/posts_providers.dart';
import '../../posts/presentation/post_widgets.dart';
import '../data/me_repository.dart';
import '../me_providers.dart';

/// Tab "Lịch đăng" của màn 10: các kèo đã hẹn giờ tự đăng, theo đội mình quản lý.
class PostSchedulesTab extends ConsumerWidget {
  const PostSchedulesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(managedTeamsProvider);
    if (teams.isEmpty) {
      return const _Empty(text: 'Chỉ đội trưởng hoặc đội phó mới hẹn lịch đăng kèo');
    }
    final team = teams.first;
    final value = ref.watch(postSchedulesProvider(team.teamId));
    Future<Object?> refresh() => ref.refresh(postSchedulesProvider(team.teamId).future);
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AsyncView(
            value: value,
            onRetry: refresh,
            data: (items) => ScheduleList(
              schedules: items,
              onCancel: (s) async {
                await ref.read(meRepositoryProvider).cancelSchedule(team.teamId, s.id);
                ref.invalidate(postSchedulesProvider(team.teamId));
              },
            ),
          ),
          const SizedBox(height: 4),
          SoftButton(label: 'Đăng kèo mới', onPressed: () => context.push(Routes.postNew)),
        ],
      ),
    );
  }
}

/// Danh sách lịch đang chờ đăng (bỏ lịch đã huỷ), có trạng thái trống.
class ScheduleList extends StatelessWidget {
  const ScheduleList({super.key, required this.schedules, required this.onCancel});
  final List<PostScheduleDto> schedules;
  final Future<void> Function(PostScheduleDto) onCancel;

  @override
  Widget build(BuildContext context) {
    final active = [
      for (final s in schedules)
        if (s.status == PostScheduleDtoStatus.scheduled) s,
    ];
    if (active.isEmpty) {
      return const _Empty(
        text: 'Chưa có kèo nào hẹn giờ đăng',
        hint: 'Hẹn lịch khi đăng kèo mới để kèo tự lên Bảng tin đúng giờ.',
      );
    }
    return Column(
      children: [
        for (final s in active) ...[
          ScheduleCard(schedule: s, onCancel: () => onCancel(s)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

/// Thẻ một lịch đăng: giờ tự đăng, lặp tuần, kèo sẽ đăng và nút huỷ có xác nhận.
class ScheduleCard extends StatefulWidget {
  const ScheduleCard({super.key, required this.schedule, required this.onCancel});
  final PostScheduleDto schedule;
  final Future<void> Function() onCancel;

  @override
  State<ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<ScheduleCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Huỷ lịch đăng?'),
        content: const Text('Kèo này sẽ không tự lên Bảng tin nữa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Giữ lại')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Huỷ lịch')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runAction(context, widget.onCancel, success: 'Đã huỷ lịch đăng');
    if (mounted && !done) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final post = s.post;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tự đăng ${Fmt.slot(s.scheduledAt)}${s.repeatWeekly ? ' · lặp hằng tuần' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${Labels.postType(post.type)} · đá ${Fmt.slot(post.startAt)}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          if (post.pitchName != null)
            Text(
              post.pitchName!,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: AppSizes.tapTarget,
              child: TextButton(
                onPressed: _busy ? null : _cancel,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Huỷ lịch'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
