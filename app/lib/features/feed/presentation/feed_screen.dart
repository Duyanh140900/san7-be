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
import '../../../core/widgets/live_ticker.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/team_crest.dart';
import '../../chat/data/chat_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../pitches/pitches_providers.dart';
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

/// Màn 1 · Bảng tin cáp kèo v2 "Floodlight Night".
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
      backgroundColor: AppColors.surfaceCard,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final a in ['', ...Labels.areas])
              ListTile(
                title: Text(
                  a.isEmpty ? 'Mọi khu vực' : a,
                  style: TextStyle(
                    color: (a.isEmpty ? current == null : current == a)
                        ? AppColors.lime
                        : AppColors.textMain,
                    fontWeight: (a.isEmpty ? current == null : current == a)
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                trailing: (a.isEmpty ? current == null : current == a)
                    ? const Icon(Icons.check, color: AppColors.lime)
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
    final unreadNoti = ref.watch(unreadCountProvider).value ?? 0;
    final unreadInbox = ref.watch(inboxProvider).value?.unreadTotal ?? 0;
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
          ref.invalidate(inboxProvider);
          ref.invalidate(freeSlotsProvider);
          return ref.refresh(feedProvider.future);
        },
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLine.toUpperCase(),
                        style: AppText.label.copyWith(color: AppColors.textDim),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bảng tin',
                        style: AppText.display(28, color: AppColors.textMain),
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
                      ? const AppIcon(AppIcons.close, size: 20, color: AppColors.textMain)
                      : const AppIcon(AppIcons.search, size: 20, color: AppColors.textMain),
                ),
                const SizedBox(width: 8),
                _IconCircle(
                  label: 'Tin nhắn',
                  onTap: () => context.push(Routes.inbox),
                  dot: unreadInbox > 0,
                  child: const Icon(Icons.mail_outline, size: 20, color: AppColors.textMain),
                ),
                const SizedBox(width: 8),
                _IconCircle(
                  label: 'Thông báo',
                  onTap: () => context.push(Routes.notifications),
                  dot: unreadNoti > 0,
                  child: const AppIcon(AppIcons.bell, size: 20, color: AppColors.textMain),
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
                style: const TextStyle(color: AppColors.textMain),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 400),
                    () => ref.read(feedFilterProvider.notifier).setQuery(v),
                  );
                },
                onSubmitted: (v) => ref.read(feedFilterProvider.notifier).setQuery(v),
                decoration: InputDecoration(
                  hintText: 'Tìm đội, sân, khu vực, nội dung kèo',
                  hintStyle: const TextStyle(color: AppColors.textDim),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textDim),
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Dải LIVE Ticker (full chiều ngang)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: const LiveTicker(
                items: [
                  TickerItem('12 sân trống quanh bạn tối nay', color: AppColors.lime, live: true),
                  TickerItem('Thanh Xuân Utd 3–2 FC Cầu Giấy', color: AppColors.textMain),
                  TickerItem('Hoàng Mai FC tìm thủ môn CN 8:00', color: AppColors.textMuted),
                  TickerItem('Đức Hùng dẫn đầu Vua phá lưới · 9 bàn', color: AppColors.trophy),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Dải Bộ lọc (nút Màn 30 + loại bài + khu vực)
            SizedBox(
              height: AppSizes.tapTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  _FilterButton(
                    count: filter.advancedCount,
                    onTap: () => context.push(Routes.feedFilter),
                  ),
                  const SizedBox(width: 8),
                  FilterPill(
                    label: 'Tất cả',
                    selected: filter.type == null,
                    onTap: () => ref.read(feedFilterProvider.notifier).setType(null),
                  ),
                  for (final t in Labels.postTypes) ...[
                    const SizedBox(width: 8),
                    FilterPill(
                      label: t.$2,
                      selected: filter.type == t.$1,
                      onTap: () => ref.read(feedFilterProvider.notifier).setType(t.$1),
                    ),
                  ],
                  const SizedBox(width: 8),
                  FilterPill(
                    label: '${filter.area ?? 'Mọi khu vực'} ▾',
                    selected: filter.area != null,
                    onTap: _pickArea,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Khối "Sân trống tối nay" gọi GET /v1/pitches/free-slots
            const _FreeSlotsSection(),
            const SizedBox(height: 14),

            // Composer đăng kèo nhanh nếu có đội
            if (managed.isNotEmpty) ...[
              _Composer(
                teamName: managed.first.name,
                crest: managed.first.crestColor,
              ),
              const SizedBox(height: 14),
            ],

            // Feed Content
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.lime : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.lime : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune,
              size: 16,
              color: active ? AppColors.ink : AppColors.textMain,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Lọc ($count)' : 'Bộ lọc',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.ink : AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khối "Sân trống tối nay" gọi GET /v1/pitches/free-slots
class _FreeSlotsSection extends ConsumerWidget {
  const _FreeSlotsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(freeSlotsProvider);
    return slotsAsync.when(
      data: (slots) {
        if (slots.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SÂN TRỐNG TỐI NAY', style: AppText.label),
                  LinkButton(
                    'Mở bản đồ',
                    onTap: () => context.go(Routes.pitches),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: slots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final s = slots[i];
                  return _FreeSlotCard(slot: s);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _FreeSlotCard extends StatelessWidget {
  const _FreeSlotCard({required this.slot});
  final FreePitchSlotDto slot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: InkWell(
        onTap: () => context.push(Routes.pitch(slot.pitchId)),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Fmt.time(slot.slotStart),
                style: AppText.score(22, color: AppColors.lime),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (slot.distanceKm != null) '${slot.distanceKm!.toStringAsFixed(1)} km',
                      '★ ${slot.rating.toStringAsFixed(1)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textDim),
                  ),
                ],
              ),
            ],
          ),
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
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
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
                    color: AppColors.lime,
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
          TeamCrest(name: teamName, color: crest, width: 38),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Đội bạn muốn cáp kèo tối nay?',
              style: TextStyle(fontSize: 14, color: AppColors.textDim),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              'Đăng kèo',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 13,
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
        const AppIcon(AppIcons.ball, size: 36, color: AppColors.textDim),
        const SizedBox(height: 12),
        Text(
          searching ? 'Không tìm thấy kèo phù hợp' : 'Chưa có kèo nào',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          searching
              ? 'Thử từ khoá khác hoặc bỏ bớt bộ lọc.'
              : 'Thử đổi khu vực hoặc đăng kèo đầu tiên cho đội bạn.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textDim),
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
          TeamCrest(name: t.name, color: t.crestColor, width: 44),
          const SizedBox(height: 6),
          Text(
            t.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KẾT QUẢ TRẬN · ${Fmt.dayMonth(result.playedAt).toUpperCase()}',
                style: AppText.label.copyWith(color: AppColors.textDim),
              ),
              const StatusChip(StatusKind.result),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              team(result.teamA),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${result.teamA.score} : ${result.teamB.score}',
                  style: AppText.score(30, color: AppColors.lime),
                ),
              ),
              team(result.teamB),
            ],
          ),
          if (scorers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Ghi bàn: $scorers',
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textBody),
            ),
          ],
          if (result.mvpName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const AppIcon(AppIcons.trophy, size: 16, color: AppColors.trophy),
                const SizedBox(width: 6),
                Text(
                  'MVP ${result.mvpName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.trophy,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
