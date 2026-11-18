import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/team_crest.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../posts/data/posts_repository.dart';
import '../../posts/posts_providers.dart';
import '../../posts/presentation/post_widgets.dart';

const _weekdaysLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// Màn 1 · Bảng tin: kèo đang mở theo loại và khu vực.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();
  final _query = TextEditingController();
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(feedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    final current = ref.read(feedFilterProvider).area;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in ['', ...Labels.areas])
              ListTile(
                title: Text(a.isEmpty ? 'Mọi khu vực' : a),
                trailing: (a.isEmpty ? current == null : current == a)
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref
          .read(feedFilterProvider.notifier)
          .setArea(picked.isEmpty ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(feedFilterProvider);
    final feed = ref.watch(feedProvider);
    final managed = ref.watch(managedTeamsProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final auth = ref.watch(authControllerProvider);
    final myName = auth is AuthSignedIn ? auth.me.name : '';
    final now = Fmt.vn(DateTime.now());
    final dateLine =
        '${_weekdaysLong[now.weekday - 1]}, ${now.day} tháng ${now.month}';

    bool canRequest(PostDto p) => managed.any((t) => t.teamId != p.team.id);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(unreadCountProvider);
          return ref.refresh(feedProvider.future);
        },
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLine.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bảng tin',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
                _IconCircle(
                  label: _searching ? 'Đóng tìm kiếm' : 'Tìm kiếm',
                  onTap: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _query.clear();
                      _debounce?.cancel();
                      ref.read(feedFilterProvider.notifier).setQuery('');
                    }
                  }),
                  child: _searching
                      ? const Icon(Icons.close, size: 20)
                      : const AppIcon(AppIcons.search),
                ),
                const SizedBox(width: 8),
                _IconCircle(
                  label: 'Thông báo',
                  onTap: () => context.push(Routes.notifications),
                  dot: unread > 0,
                  child: const AppIcon(AppIcons.bell),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Trang cá nhân',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push(Routes.me),
                    child: Avatar(
                      name: myName.isEmpty ? '?' : myName,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            if (_searching) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 400),
                    () => ref.read(feedFilterProvider.notifier).setQuery(v),
                  );
                },
                onSubmitted: (v) => ref.read(feedFilterProvider.notifier).setQuery(v),
                decoration: const InputDecoration(
                  hintText: 'Tìm đội, sân, khu vực, nội dung kèo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  FilterPill(
                    label: 'Tất cả',
                    selected: filter.type == null,
                    onTap: () =>
                        ref.read(feedFilterProvider.notifier).setType(null),
                  ),
                  for (final t in Labels.postTypes)
                    FilterPill(
                      label: t.$2,
                      selected: filter.type == t.$1,
                      onTap: () =>
                          ref.read(feedFilterProvider.notifier).setType(t.$1),
                    ),
                  FilterPill(
                    label: '${filter.area ?? 'Mọi khu vực'} ▾',
                    selected: filter.area != null,
                    onTap: _pickArea,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (managed.isNotEmpty) ...[
              _Composer(
                teamName: managed.first.name,
                crest: managed.first.crestColor,
              ),
              const SizedBox(height: 14),
            ],
            AsyncView(
              value: feed,
              onRetry: () => ref.invalidate(feedProvider),
              data: (s) {
                final kw = filter.q.trim();
                return s.items.isEmpty
                    ? _Empty(searching: kw.isNotEmpty)
                    : Column(
                        children: [
                          for (final e in s.items) ...[
                            switch (e) {
                              PostEntry(:final post) => PostCard(
                                post: post,
                                canRequest: canRequest(post),
                              ),
                              MatchResultEntry() => _ResultCard(result: e.result),
                            },
                            const SizedBox(height: 14),
                          ],
                          if (s.loadingMore)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.label,
    required this.onTap,
    required this.child,
    this.dot = false,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool dot;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: dot ? '$label, có thông báo mới' : label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (dot)
              Positioned(
                top: -2,
                right: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.redBright,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.teamName, required this.crest});
  final String teamName;
  final String crest;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push(Routes.postNew),
    child: AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          TeamAvatar(name: teamName, color: crest),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Đội bạn muốn cáp kèo tối nay?',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              'Đăng kèo',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({this.searching = false});
  final bool searching;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const AppIcon(AppIcons.ball, size: 32, color: AppColors.textSecondary),
        const SizedBox(height: 10),
        Text(
          searching ? 'Không tìm thấy kèo phù hợp' : 'Chưa có kèo nào',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          searching
              ? 'Thử từ khoá khác hoặc bỏ bớt bộ lọc.'
              : 'Thử đổi khu vực hoặc đăng kèo đầu tiên cho đội bạn.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

/// Thẻ kết quả trận trên Bảng tin: tỉ số, người ghi bàn, MVP.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final FeedMatchResultDto result;

  @override
  Widget build(BuildContext context) {
    Widget team(ResultTeamDto t) => Expanded(
      child: Column(
        children: [
          TeamAvatar(name: t.name, color: t.crestColor, size: 44),
          const SizedBox(height: 6),
          Text(
            t.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    final scorers = result.scorers
        .map((s) => s.goals > 1 ? '${s.name} (${s.goals})' : s.name)
        .join(', ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KẾT QUẢ TRẬN · ${Fmt.dayMonth(result.playedAt)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              team(result.teamA),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${result.teamA.score}–${result.teamB.score}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              team(result.teamB),
            ],
          ),
          if (scorers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Ghi bàn: $scorers', style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (result.mvpName != null) ...[
            const SizedBox(height: 4),
            Text(
              'MVP: ${result.mvpName}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
