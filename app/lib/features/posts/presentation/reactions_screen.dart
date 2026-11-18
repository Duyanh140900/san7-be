import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/system_state.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'community_widgets.dart';

/// Màn 18 · Danh sách cảm xúc theo bài viết v2.
class ReactionsScreen extends ConsumerStatefulWidget {
  const ReactionsScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<ReactionsScreen> createState() => _ReactionsScreenState();
}

class _ReactionsScreenState extends ConsumerState<ReactionsScreen> {
  ReactionKindValue? _selected;
  final _items = <ReactionUserDto>[];
  final _scroll = ScrollController();
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 180) _loadMore();
    });
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .reactions(
            widget.postId,
            kind: _selected == null ? null : reactionOf(_selected!),
          );
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(page.items);
          _cursor = page.nextCursor;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(
          context,
          'Không tải được danh sách cảm xúc',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(postsRepositoryProvider)
          .reactions(
            widget.postId,
            cursor: cursor,
            kind: _selected == null ? null : reactionOf(_selected!),
          );
      if (mounted) {
        setState(() {
          _items.addAll(page.items);
          _cursor = page.nextCursor;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMore = false);
        showToast(
          context,
          'Không tải thêm được cảm xúc',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(postReactionsProvider(widget.postId)).value;
    final totalReactions = summary?.counts.fold(0, (sum, item) => sum + item.count);
    int count(ReactionKindValue kind) {
      final Iterable<ReactionCountDto> counts =
          summary?.counts.where((item) => item.kind == reactionOf(kind)) ??
          const <ReactionCountDto>[];
      return counts.fold(0, (sum, item) => sum + item.count);
    }

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Cảm xúc'),
            SizedBox(
              height: AppSizes.tapTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  FilterPill(
                    label: 'Tất cả ${totalReactions != null ? '($totalReactions)' : ''}',
                    selected: _selected == null,
                    onTap: () {
                      setState(() => _selected = null);
                      _load();
                    },
                  ),
                  for (final kind in ReactionKindValue.values) ...[
                    const SizedBox(width: 8),
                    FilterPill(
                      label: '${reactionEmoji(reactionOf(kind))} ${count(kind)}',
                      selected: _selected == kind,
                      onTap: () {
                        setState(() => _selected = kind);
                        _load();
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: _loading
                  ? const Center(child: LoadingState(compact: true))
                  : _items.isEmpty
                  ? const Center(
                      child: EmptyState(
                        title: 'Chưa có cảm xúc nào',
                        message: 'Thả cảm xúc đầu tiên cho bài viết.',
                        compact: true,
                      ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _items.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        if (index == _items.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final item = _items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(AppRadius.button),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              Avatar(name: item.name, url: item.avatarUrl, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                              Text(
                                reactionEmoji(item.kind),
                                style: const TextStyle(fontSize: 22),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
