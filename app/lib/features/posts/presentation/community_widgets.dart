import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';

const _reactionKinds = ReactionKindValue.values;

String reactionEmoji(ReactionKind kind) => switch (kind) {
  ReactionKindKnown(value: ReactionKindValue.like) => '👍',
  ReactionKindKnown(value: ReactionKindValue.love) => '❤️',
  ReactionKindKnown(value: ReactionKindValue.fire) => '🔥',
  ReactionKindKnown(value: ReactionKindValue.haha) => '😂',
  ReactionKindKnown(value: ReactionKindValue.sad) => '😢',
  ReactionKindUnknown() => '•',
};

String reactionLabel(ReactionKindValue kind) => switch (kind) {
  ReactionKindValue.like => 'Thích',
  ReactionKindValue.love => 'Yêu thích',
  ReactionKindValue.fire => 'Hay quá',
  ReactionKindValue.haha => 'Haha',
  ReactionKindValue.sad => 'Buồn',
};

ReactionKind reactionOf(ReactionKindValue kind) => switch (kind) {
  ReactionKindValue.like => ReactionKind.like,
  ReactionKindValue.love => ReactionKind.love,
  ReactionKindValue.fire => ReactionKind.fire,
  ReactionKindValue.haha => ReactionKind.haha,
  ReactionKindValue.sad => ReactionKind.sad,
};

/// Thanh cảm xúc và bình luận dùng ở thẻ Bảng tin lẫn Chi tiết kèo.
class PostCommunityBar extends ConsumerWidget {
  const PostCommunityBar({
    super.key,
    required this.postId,
    this.canManageComments = false,
    this.compact = false,
  });

  final String postId;
  final bool canManageComments;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(postReactionsProvider(postId)).value;
    final counts = page?.counts ?? const <ReactionCountDto>[];
    final reacted = page?.myKind;
    final total = counts.fold<int>(0, (sum, item) => sum + item.count);
    final visible = [
      for (final item in counts)
        if (item.count > 0) item.kind,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0)
          Semantics(
            button: true,
            label: '$total cảm xúc',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.group),
              onTap: () => context.push(Routes.postReactions(postId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final kind in visible.take(3)) Text(reactionEmoji(kind)),
                    const SizedBox(width: 6),
                    Text(
                      '$total',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: AppIcons.heart,
                emoji: reacted == null ? null : reactionEmoji(reacted),
                label: reacted == null ? 'Cảm xúc' : 'Đã bày tỏ',
                selected: reacted != null,
                onTap: () => _showReactionPicker(context, ref, postId, reacted),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: AppIcons.comment,
                label: compact ? 'Bình luận' : 'Bình luận',
                onTap: () => showCommentsSheet(
                  context,
                  postId: postId,
                  canManageComments: canManageComments,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emoji,
    this.selected = false,
  });
  final AppIcons icon;
  final String? emoji;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.group),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 16))
              else
                AppIcon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showReactionPicker(
  BuildContext context,
  WidgetRef ref,
  String postId,
  ReactionKind? active,
) async {
  final picked = await showModalBottomSheet<ReactionKindValue?>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final kind in _reactionKinds)
              Semantics(
                button: true,
                label: reactionLabel(kind),
                selected: active == reactionOf(kind),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  onTap: () => Navigator.pop(context, kind),
                  child: SizedBox(
                    width: AppSizes.tapTarget,
                    height: AppSizes.tapTarget,
                    child: Center(
                      child: Text(
                        reactionEmoji(reactionOf(kind)),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  if (!context.mounted) return;
  final next = reactionOf(picked);
  final ok = await runAction(
    context,
    () => active == next
        ? ref.read(postsRepositoryProvider).removeReaction(postId)
        : ref.read(postsRepositoryProvider).setReaction(postId, next),
  );
  if (ok) ref.invalidate(postReactionsProvider(postId));
}

Future<void> showCommentsSheet(
  BuildContext context, {
  required String postId,
  required bool canManageComments,
}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  backgroundColor: AppColors.surface,
  builder: (_) => _CommentsSheet(postId: postId, canManageComments: canManageComments),
);

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId, required this.canManageComments});
  final String postId;
  final bool canManageComments;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _comments = <CommentDto>[];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 180) _loadMore();
    });
    Future<void>.microtask(_loadInitial);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final page = await ref.read(postsRepositoryProvider).comments(widget.postId);
      if (mounted) {
        setState(() {
          _comments
            ..clear()
            ..addAll(page.items);
          _nextCursor = page.nextCursor;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(context, 'Không tải được bình luận', type: ToastType.error);
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(postsRepositoryProvider).comments(widget.postId, cursor: cursor);
      if (mounted) {
        setState(() {
          _comments.addAll(page.items);
          _nextCursor = page.nextCursor;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
        showToast(context, 'Không tải thêm được bình luận', type: ToastType.error);
      }
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await ref.read(postsRepositoryProvider).addComment(widget.postId, body);
      if (mounted) {
        setState(() {
          _comments.insert(0, comment);
          _input.clear();
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        showToast(context, 'Không gửi được bình luận', type: ToastType.error);
      }
    }
  }

  Future<void> _delete(CommentDto comment) async {
    final ok = await runAction(
      context,
      () => ref.read(postsRepositoryProvider).deleteComment(widget.postId, comment.id),
      success: 'Đã xóa bình luận',
    );
    if (ok && mounted) {
      setState(() => _comments.removeWhere((item) => item.id == comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider);
    final myId = me is AuthSignedIn ? me.me.id : null;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Bình luận',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có bình luận nào',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: _comments.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          if (index == _comments.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final comment = _comments[index];
                          final allowed = widget.canManageComments || comment.author.id == myId;
                          return _CommentTile(
                            comment: comment,
                            canDelete: allowed,
                            onDelete: () => _delete(comment),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('comment-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          hintText: 'Viết bình luận...',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(AppRadius.group)),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: AppSizes.tapTarget,
                      height: AppSizes.tapTarget,
                      child: FilledButton(
                        key: const Key('comment-send'),
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        child: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Gửi'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.canDelete, required this.onDelete});
  final CommentDto comment;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Avatar(name: comment.author.name, url: comment.author.avatarUrl, size: 36),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comment.author.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  Fmt.ago(comment.createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (canDelete)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                    ),
                    child: const Text('Xóa', style: TextStyle(color: AppColors.red)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(comment.body, style: const TextStyle(fontSize: 15, height: 1.35)),
          ],
        ),
      ),
    ],
  );
}
