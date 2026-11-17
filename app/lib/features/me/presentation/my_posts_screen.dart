import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../posts/presentation/post_widgets.dart';
import '../me_providers.dart';
import 'post_schedules_tab.dart';

/// Màn 10 · Kèo của tôi: Đang mở, Lịch đăng, Đã chốt.
class MyPostsScreen extends ConsumerStatefulWidget {
  const MyPostsScreen({super.key});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen> {
  int _tab = 0;

  static const _labels = ['Đang mở', 'Lịch đăng', 'Đã chốt'];

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(myPostsProvider(PostStatus.open));
    final matched = ref.watch(myPostsProvider(PostStatus.matched));
    final labels = [
      if (open.value case final p?) 'Đang mở · ${p.items.length}' else _labels[0],
      _labels[1],
      _labels[2],
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DetailHeader(
              backLabel: 'Cá nhân',
              trailing: TextButton(
                onPressed: () => context.push(Routes.postNew),
                child: const Text('Đăng kèo mới'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Kèo của tôi', style: Theme.of(context).textTheme.displaySmall),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Segmented(
                labels: labels,
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_tab) {
                0 => _PostList(
                  value: open,
                  empty: 'Bạn chưa có kèo nào đang mở',
                  onRefresh: () => ref.refresh(myPostsProvider(PostStatus.open).future),
                ),
                1 => const PostSchedulesTab(),
                _ => _PostList(
                  value: matched,
                  empty: 'Chưa có kèo nào đã chốt',
                  onRefresh: () => ref.refresh(myPostsProvider(PostStatus.matched).future),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.value, required this.empty, required this.onRefresh});
  final AsyncValue<FeedPageDto> value;
  final String empty;
  final Future<Object?> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        AsyncView(
          value: value,
          onRetry: onRefresh,
          data: (page) => page.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(empty, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: [
                    for (final p in page.items) ...[
                      _MyPostCard(post: p),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
      ],
    ),
  );
}

class _MyPostCard extends StatelessWidget {
  const _MyPostCard({required this.post});
  final PostDto post;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => context.push(Routes.post(post.id)),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PostTypeBadge(post.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Fmt.slot(post.startAt),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [?post.pitchName, post.area].join(' · '),
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          if (post.requestCount > 0) ...[
            const SizedBox(height: 12),
            SoftButton(
              label: '${post.requestCount} đội muốn nhận · So sánh',
              onPressed: () => context.push(Routes.postCompare(post.team.id, post.id)),
            ),
          ],
        ],
      ),
    ),
  );
}
