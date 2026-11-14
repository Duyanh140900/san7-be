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
import '../../../core/widgets/team_crest.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../posts/posts_providers.dart';
import '../../posts/presentation/post_widgets.dart';

const _weekdaysLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];

/// Màn 1 · Bảng tin: kèo đang mở theo loại và khu vực.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(feedProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
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
      ref.read(feedFilterProvider.notifier).setArea(picked.isEmpty ? null : picked);
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
    final dateLine = '${_weekdaysLong[now.weekday - 1]}, ${now.day} tháng ${now.month}';

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
                      Text('Bảng tin', style: Theme.of(context).textTheme.displaySmall),
                    ],
                  ),
                ),
                _IconCircle(
                  label: 'Thông báo',
                  onTap: () => context.push(Routes.notifications),
                  dot: unread > 0,
                  child: const AppIcon(AppIcons.bell),
                ),
                const SizedBox(width: 8),
                Avatar(name: myName.isEmpty ? '?' : myName, size: 40),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  _Chip(
                    label: 'Tất cả',
                    selected: filter.type == null,
                    onTap: () => ref.read(feedFilterProvider.notifier).setType(null),
                  ),
                  for (final t in Labels.postTypes)
                    _Chip(
                      label: t.$2,
                      selected: filter.type == t.$1,
                      onTap: () => ref.read(feedFilterProvider.notifier).setType(t.$1),
                    ),
                  _Chip(
                    label: '${filter.area ?? 'Mọi khu vực'} ▾',
                    selected: filter.area != null,
                    onTap: _pickArea,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (managed.isNotEmpty) ...[
              _Composer(teamName: managed.first.name, crest: managed.first.crestColor),
              const SizedBox(height: 14),
            ],
            AsyncView(
              value: feed,
              onRetry: () => ref.invalidate(feedProvider),
              data: (s) => s.items.isEmpty
                  ? const _Empty()
                  : Column(
                      children: [
                        for (final p in s.items) ...[
                          PostCard(post: p, canRequest: canRequest(p)),
                          const SizedBox(height: 14),
                        ],
                        if (s.loadingMore)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
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
        decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
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

/// Chip lọc nền trắng, chọn thì nền đen (như bản vẽ).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.text : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.text,
            ),
          ),
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
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const AppCard(
    padding: EdgeInsets.all(24),
    child: Column(
      children: [
        AppIcon(AppIcons.ball, size: 32, color: AppColors.textSecondary),
        SizedBox(height: 10),
        Text('Chưa có kèo nào', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text(
          'Thử đổi khu vực hoặc đăng kèo đầu tiên cho đội bạn.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
