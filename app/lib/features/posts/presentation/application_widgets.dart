import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';

final postApplicationsProvider = FutureProvider.autoDispose.family<List<PostApplication>, String>(
  (ref, postId) => ref.watch(postsRepositoryProvider).applications(postId),
);

String? _positionLabel(String? v) {
  if (v == null) return null;
  for (final p in Labels.positions) {
    if (p.$1.value == v) return p.$2;
  }
  return null;
}

String applicationStatusLabel(String status) => switch (status) {
  'accepted' => 'Đã được nhận',
  'rejected' => 'Bị từ chối',
  'withdrawn' => 'Đã rút',
  _ => 'Đang chờ duyệt',
};

/// Hỏi vị trí và lời nhắn rồi gửi ứng tuyển thật. Trả true nếu gửi được.
Future<bool> applyToPost(BuildContext context, WidgetRef ref, PostDto post) async {
  final note = TextEditingController();
  String? position;
  final send = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ứng tuyển vào ${post.team.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('Vị trí muốn đá', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in Labels.positions)
                  if (post.positions.isEmpty || post.positions.any((e) => Labels.position(e) == p.$2))
                    ChoiceChip(
                      label: Text(p.$2),
                      selected: position == p.$1.value,
                      onSelected: (_) =>
                          setState(() => position = position == p.$1.value ? null : p.$1.value),
                    ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Lời nhắn cho đội trưởng (không bắt buộc)'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Gửi ứng tuyển'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  final text = note.text;
  note.dispose();
  if (send != true || !context.mounted) return false;
  try {
    await ref.read(postsRepositoryProvider).apply(post.id, position: position, note: text);
    ref.invalidate(postDetailProvider(post.id));
    if (context.mounted) showToast(context, 'Đã gửi ứng tuyển', type: ToastType.success);
    return true;
  } catch (e) {
    final err = ApiError.from(e);
    if (err.statusCode == 409) ref.invalidate(postDetailProvider(post.id));
    if (context.mounted) {
      showToast(
        context,
        err.statusCode == 409 ? 'Bạn đã ứng tuyển kèo này rồi' : err.message,
        type: err.statusCode == 409 ? ToastType.info : ToastType.error,
      );
    }
    return false;
  }
}

/// Khối "Đội hình" của kèo: cầu thủ đã chốt.
class LineupSection extends StatelessWidget {
  const LineupSection({super.key, required this.lineup});
  final List<({String name, String? position})> lineup;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Đội hình', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in lineup)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                [p.name, ?_positionLabel(p.position)].join(' · '),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    ],
  );
}

/// Danh sách ứng viên cho đội trưởng/phó: nhận hoặc từ chối.
class ApplicationsSection extends ConsumerWidget {
  const ApplicationsSection({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(postApplicationsProvider(postId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ứng viên', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        AsyncView<List<PostApplication>>(
          value: apps,
          onRetry: () => ref.invalidate(postApplicationsProvider(postId)),
          data: (list) => list.isEmpty
              ? const Text(
                  'Chưa có ai ứng tuyển.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                )
              : Column(children: [for (final a in list) _ApplicationRow(postId: postId, app: a)]),
        ),
      ],
    );
  }
}

class _ApplicationRow extends ConsumerStatefulWidget {
  const _ApplicationRow({required this.postId, required this.app});
  final String postId;
  final PostApplication app;

  @override
  ConsumerState<_ApplicationRow> createState() => _ApplicationRowState();
}

class _ApplicationRowState extends ConsumerState<_ApplicationRow> {
  bool _busy = false;

  Future<void> _review(String status, String done) async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      () => ref.read(postsRepositoryProvider).reviewApplication(
        widget.postId,
        widget.app.id,
        status,
      ),
      success: done,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(postApplicationsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final pending = a.status == 'pending';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [a.name, ?_positionLabel(a.position)].join(' · '),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                if (a.note != null && a.note!.isNotEmpty)
                  Text(
                    a.note!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                if (!pending)
                  Text(
                    applicationStatusLabel(a.status),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (pending) ...[
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: AppColors.red,
              ),
              onPressed: _busy ? null : () => _review('rejected', 'Đã từ chối'),
              child: const Text('Từ chối'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _busy ? null : () => _review('accepted', 'Đã nhận cầu thủ'),
              child: const Text('Nhận'),
            ),
          ],
        ],
      ),
    );
  }
}
