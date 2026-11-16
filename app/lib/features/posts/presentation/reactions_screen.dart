import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'community_widgets.dart';
import 'post_widgets.dart';

/// Màn 24 · Danh sách cảm xúc, có tab theo năm loại cảm xúc.
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
    int count(ReactionKindValue kind) {
      final Iterable<ReactionCountDto> counts =
          summary?.counts.where((item) => item.kind == reactionOf(kind)) ??
          const <ReactionCountDto>[];
      return counts.fold(0, (sum, item) => sum + item.count);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const DetailHeader(backLabel: 'Quay lại', title: 'Cảm xúc'),
            SizedBox(
              height: AppSizes.tapTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _ReactionTab(
                    label: 'Tất cả',
                    selected: _selected == null,
                    onTap: () {
                      setState(() => _selected = null);
                      _load();
                    },
                  ),
                  for (final kind in ReactionKindValue.values)
                    _ReactionTab(
                      label:
                          '${reactionEmoji(reactionOf(kind))} ${count(kind)}',
                      selected: _selected == kind,
                      onTap: () {
                        setState(() => _selected = kind);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có cảm xúc nào',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const Divider(color: AppColors.divider),
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
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Avatar(name: item.name, url: item.avatarUrl),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            reactionEmoji(item.kind),
                            style: const TextStyle(fontSize: 20),
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

class _ReactionTab extends StatelessWidget {
  const _ReactionTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.pillBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}
