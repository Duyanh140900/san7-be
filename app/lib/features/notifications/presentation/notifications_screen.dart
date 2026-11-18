import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/system_state.dart';
import '../data/notifications_repository.dart';

const _filters = <(NotificationCategoryValue?, String)>[
  (null, 'Tất cả'),
  (NotificationCategoryValue.match, 'Kèo'),
  (NotificationCategoryValue.booking, 'Đặt sân'),
  (NotificationCategoryValue.team, 'Đội'),
  (NotificationCategoryValue.fund, 'Quỹ'),
];

/// Màn 15 · Thông báo.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationCategoryValue? _category;

  void _refresh() {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _markAll() async {
    final ok = await runAction(context, () => ref.read(notificationsRepositoryProvider).markRead());
    if (ok) _refresh();
  }

  Future<void> _open(NotificationDto n) async {
    if (!n.read) {
      ref.read(notificationsRepositoryProvider).markRead([n.id]).then((_) => _refresh()).ignore();
    }
    final p = n.payload;
    if (n.type.startsWith('match.') && p.matchId != null && p.teamId != null) {
      await context.push(Routes.matchResult(p.teamId!, p.matchId!));
    } else if (p.bookingId != null && p.teamId != null) {
      await context.push(Routes.booking(p.teamId!, p.bookingId!));
    } else if (p.requestId != null && p.teamId != null) {
      await context.push(Routes.request(p.teamId!, p.requestId!));
    } else if (p.postId != null) {
      await context.push(Routes.post(p.postId!));
    } else if (p.eventId != null) {
      await context.push(Routes.teamEvent(p.eventId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(notificationsProvider(_category));
    final unread = ref.watch(unreadCountProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Thông báo',
              titleSuffix: (unread ?? 0) > 0
                  ? const AppIcon(AppIcons.bell, size: 20, color: AppColors.lime)
                  : null,
              trailing: LinkButton('Đánh dấu đã đọc', onTap: _markAll),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(unreadCountProvider);
                  return ref.refresh(notificationsProvider(_category).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    SizedBox(
                      height: AppSizes.tapTarget,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in _filters)
                            Center(
                              child: SizedBox(
                                height: AppSizes.tapTarget,
                                child: FilterPill(
                                  label: f.$2,
                                  selected: _category == f.$1,
                                  onTap: () => setState(() => _category = f.$1),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AsyncView(
                      value: page,
                      onRetry: _refresh,
                      data: (p) => p.items.isEmpty
                          ? const EmptyState(
                              message: 'Chưa có thông báo nào. Có kèo mới là sân báo ngay.',
                              compact: true,
                            )
                          : _List(items: p.items, onOpen: _open),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.onOpen});
  final List<NotificationDto> items;
  final ValueChanged<NotificationDto> onOpen;

  /// Yêu cầu nhận kèo mới (chưa đọc, trong 2 giờ): thẻ nổi bật có nút xác nhận.
  bool _urgent(NotificationDto n) =>
      !n.read &&
      n.type == 'request.received' &&
      DateTime.now().difference(n.createdAt) < const Duration(hours: 2);

  @override
  Widget build(BuildContext context) {
    final urgent = items.where(_urgent).toList();
    final rest = items.where((n) => !_urgent(n)).toList();
    final today = Fmt.vn(DateTime.now());
    bool isToday(DateTime t) {
      final v = Fmt.vn(t);
      return v.year == today.year && v.month == today.month && v.day == today.day;
    }

    final groups = [
      ('Hôm nay', rest.where((n) => isToday(n.createdAt)).toList()),
      ('Trước đó', rest.where((n) => !isToday(n.createdAt)).toList()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final n in urgent) ...[
          _UrgentCard(n: n, onTap: () => onOpen(n)),
          const SizedBox(height: 14),
        ],
        for (final (title, list) in groups)
          if (list.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Text(title.toUpperCase(), style: AppText.label),
            ),
            for (final n in list) ...[_Row(n: n, onTap: () => onOpen(n)), const SizedBox(height: 6)],
          ],
      ],
    );
  }
}

/// Ô icon bo 14 theo loại thông báo.
Widget _icon(NotificationDto n, {double size = 40}) {
  final (bg, fg, icon) = switch (n.type) {
    'match.result_confirmed' => (AppColors.greenSoft, AppColors.greenSoftText, AppIcons.checkCircle),
    'match.prompt_result' || 'match.result_reported' => (
      AppColors.primarySoft,
      AppColors.lime,
      AppIcons.ball,
    ),
    'request.accepted' => (AppColors.greenSoft, AppColors.greenSoftText, AppIcons.checkCircle),
    'request.received' => (AppColors.primarySoft, AppColors.lime, AppIcons.ball),
    _ when n.category == NotificationCategory.booking => (
      AppColors.homeText.withValues(alpha: 0.14),
      AppColors.homeText,
      AppIcons.pin,
    ),
    'request.expired' => (AppColors.warnSoft, AppColors.warnText, AppIcons.clock),
    _ when n.category == NotificationCategory.fund => (
      AppColors.warnSoft,
      AppColors.trophy,
      AppIcons.wallet,
    ),
    _ when n.category == NotificationCategory.match => (
      AppColors.orangeSoft,
      AppColors.orangeText,
      AppIcons.ball,
    ),
    _ => (AppColors.surfaceHigh, AppColors.textMain, AppIcons.bell),
  };
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    alignment: Alignment.center,
    child: AppIcon(icon, color: fg),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.n, required this.onTap});
  final NotificationDto n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: n.read ? AppColors.surfaceCard.withValues(alpha: 0) : AppColors.primaryTint,
    borderRadius: BorderRadius.circular(AppRadius.tile),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _icon(n),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                      color: n.read ? AppColors.textBody : AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${Fmt.ago(n.createdAt)} · ${n.body}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            if (!n.read)
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    ),
  );
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.n, required this.onTap});
  final NotificationDto n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deadline = n.createdAt.add(const Duration(hours: 2));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.orangeSoft, AppColors.surfaceCard],
        ),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.hot.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icon(n, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Fmt.ago(n.createdAt)} · ${n.body}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.hot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Countdown(
                  target: deadline,
                  builder: (_, left) => Text(
                    'Tự huỷ sau ${Fmt.remaining(left)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.hotText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              LimeButton(label: 'Xem & xác nhận', onPressed: onTap, height: AppSizes.tapTarget),
            ],
          ),
        ],
      ),
    );
  }
}
