import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/status_chip.dart';
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
      return const _Empty(
        text: 'Chỉ đội trưởng hoặc đội phó mới hẹn lịch đăng kèo',
      );
    }
    final team = teams.first;
    final value = ref.watch(postSchedulesProvider(team.teamId));
    Future<Object?> refresh() =>
        ref.refresh(postSchedulesProvider(team.teamId).future);
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
                await ref
                    .read(meRepositoryProvider)
                    .cancelSchedule(team.teamId, s.id);
                ref.invalidate(postSchedulesProvider(team.teamId));
              },
              onUpdate: (s, edit) async {
                await ref
                    .read(meRepositoryProvider)
                    .updateSchedule(
                      team.teamId,
                      s.id,
                      time: edit.time,
                      weekday: edit.weekday,
                      pausedUntil: edit.pausedUntil,
                      resume: edit.resume,
                    );
                ref.invalidate(postSchedulesProvider(team.teamId));
              },
            ),
          ),
          const SizedBox(height: 4),
          SoftButton(
            label: 'Đăng kèo mới',
            onPressed: () => context.push(Routes.postNew),
          ),
        ],
      ),
    );
  }
}

/// Danh sách lịch đang chờ đăng (bỏ lịch đã huỷ), có trạng thái trống.
class ScheduleList extends StatelessWidget {
  const ScheduleList({
    super.key,
    required this.schedules,
    required this.onCancel,
    this.onUpdate,
  });
  final List<PostScheduleDto> schedules;
  final Future<void> Function(PostScheduleDto) onCancel;
  final Future<void> Function(PostScheduleDto, ScheduleEdit)? onUpdate;

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
          ScheduleCard(
            schedule: s,
            onCancel: () => onCancel(s),
            onUpdate: onUpdate == null ? null : (edit) => onUpdate!(s, edit),
          ),
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
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Thay đổi gửi lên `PATCH post-schedules`: sửa giờ/thứ hoặc tạm dừng/tiếp tục.
class ScheduleEdit {
  const ScheduleEdit({
    this.time,
    this.weekday,
    this.pausedUntil,
    this.resume = false,
  });
  final String? time;
  final int? weekday;
  final DateTime? pausedUntil;
  final bool resume;
}

const _weekdayNames = [
  'Chủ nhật',
  'Thứ hai',
  'Thứ ba',
  'Thứ tư',
  'Thứ năm',
  'Thứ sáu',
  'Thứ bảy',
];

/// Thẻ một lịch đăng: giờ tự đăng, lặp tuần, kèo sẽ đăng, sửa giờ, tạm dừng và huỷ có xác nhận.
class ScheduleCard extends StatefulWidget {
  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onCancel,
    this.onUpdate,
  });
  final PostScheduleDto schedule;
  final Future<void> Function() onCancel;
  final Future<void> Function(ScheduleEdit)? onUpdate;

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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Huỷ lịch'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final done = await runAction(
      context,
      widget.onCancel,
      success: 'Đã huỷ lịch đăng',
    );
    if (mounted && !done) setState(() => _busy = false);
  }

  DateTime? get _pausedUntil {
    final v = widget.schedule.pausedUntil;
    return v != null && v.isAfter(DateTime.now()) ? v.toLocal() : null;
  }

  Future<void> _apply(ScheduleEdit edit, String success) async {
    setState(() => _busy = true);
    final done = await runAction(
      context,
      () => widget.onUpdate!(edit),
      success: success,
    );
    if (mounted && !done) setState(() => _busy = false);
  }

  Future<void> _editTime() async {
    final s = widget.schedule;
    final at = s.scheduledAt.toLocal();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: at.hour, minute: at.minute),
      helpText: 'Giờ tự đăng',
      cancelText: 'Huỷ',
      confirmText: 'Lưu',
    );
    if (picked == null || !mounted) return;
    int? weekday;
    if (s.repeatWeekly) {
      weekday = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Lặp vào thứ mấy?'),
          children: [
            for (var i = 0; i < 7; i++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, i),
                child: Text(
                  _weekdayNames[i],
                  style: TextStyle(
                    fontWeight: i == at.weekday % 7 ? FontWeight.w700 : null,
                  ),
                ),
              ),
          ],
        ),
      );
      if (weekday == null || !mounted) return;
    }
    final time =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _apply(
      ScheduleEdit(time: time, weekday: weekday),
      'Đã cập nhật giờ đăng',
    );
  }

  Future<void> _pause() async {
    final days = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, d) in const [
              ('Tạm dừng 1 tuần', 7),
              ('Tạm dừng 2 tuần', 14),
              ('Tạm dừng 1 tháng', 30),
            ])
              ListTile(title: Text(label), onTap: () => Navigator.pop(ctx, d)),
          ],
        ),
      ),
    );
    if (days == null || !mounted) return;
    await _apply(
      ScheduleEdit(pausedUntil: DateTime.now().add(Duration(days: days))),
      'Đã tạm dừng lịch đăng',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.schedule;
    final post = s.post;
    final paused = _pausedUntil;
    final canEdit = widget.onUpdate != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(
                post.type == PostType.recruit ? StatusKind.recruit : StatusKind.findOpponent,
                label: paused != null ? 'ĐÃ TẠM DỪNG' : Labels.postType(post.type).toUpperCase(),
              ),
              const Spacer(),
              Text('LẦN TỚI', style: AppText.label.copyWith(color: AppColors.textDim)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tự đăng ${Fmt.slot(s.scheduledAt)}${s.repeatWeekly ? ' · lặp hằng tuần' : ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (s.repeatWeekly) ...[
            const SizedBox(height: 8),
            _WeekdayDots(weekday: s.scheduledAt.toLocal().weekday % 7),
          ],
          if (paused != null) ...[
            const SizedBox(height: 4),
            Text(
              'Đang tạm dừng đến ${Fmt.dayMonth(paused)}',
              style: const TextStyle(fontSize: 13, color: AppColors.warnText),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${Labels.postType(post.type)} · đá ${Fmt.slot(post.startAt)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (post.pitchName != null)
            Text(
              post.pitchName!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              if (canEdit) ...[
                SizedBox(
                  height: AppSizes.tapTarget,
                  child: TextButton(
                    onPressed: _busy ? null : _editTime,
                    child: const Text('Sửa giờ'),
                  ),
                ),
                SizedBox(
                  height: AppSizes.tapTarget,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : paused != null
                        ? () => _apply(
                            const ScheduleEdit(resume: true),
                            'Đã tiếp tục lịch đăng',
                          )
                        : _pause,
                    child: Text(paused != null ? 'Tiếp tục' : 'Tạm dừng'),
                  ),
                ),
              ],
              SizedBox(
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
            ],
          ),
        ],
      ),
    );
  }
}

/// Dải T2..CN, tô lime ngày đăng lặp (bản vẽ màn 14).
class _WeekdayDots extends StatelessWidget {
  const _WeekdayDots({required this.weekday});

  /// 0 = Chủ nhật … 6 = Thứ bảy
  final int weekday;

  static const _names = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 7; i++) ...[
        Expanded(
          child: Container(
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (i + 1) % 7 == weekday ? AppColors.lime : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _names[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: (i + 1) % 7 == weekday ? AppColors.ink : AppColors.textDim,
              ),
            ),
          ),
        ),
        if (i < 6) const SizedBox(width: 4),
      ],
    ],
  );
}
