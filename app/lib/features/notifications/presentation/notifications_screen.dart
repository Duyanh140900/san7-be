import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../posts/presentation/post_widgets.dart';
import '../data/notifications_repository.dart';

const _filters = <(NotificationCategoryValue?, String)>[
  (null, 'Tất cả'),
  (NotificationCategoryValue.match, 'Kèo'),
  (NotificationCategoryValue.booking, 'Đặt sân'),
  (NotificationCategoryValue.team, 'Đội'),
  (NotificationCategoryValue.fund, 'Quỹ'),
];

/// Màn 8 · Thông báo.
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
    if (p.requestId != null && p.teamId != null) {
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(
              backLabel: 'Bảng tin',
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Thông báo', style: Theme.of(context).textTheme.displaySmall),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in _filters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _category = f.$1),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _category == f.$1 ? AppColors.text : AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    f.$2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _category == f.$1 ? Colors.white : AppColors.text,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AsyncView(
                      value: page,
                      onRetry: _refresh,
                      data: (p) => p.items.isEmpty
                          ? const AppCard(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Chưa có thông báo nào.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
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
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: ColoredBox(
                color: AppColors.surface,
                child: Column(
                  children: [
                    for (final (i, n) in list.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      _Row(n: n, onTap: () => onOpen(n)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

/// Icon tròn theo loại thông báo.
Widget _icon(NotificationDto n) {
  final (bg, fg, icon) = switch (n.type) {
    'request.accepted' => (AppColors.greenSoft, AppColors.greenSoftText, AppIcons.checkCircle),
    'request.received' => (AppColors.primarySoft, AppColors.primarySoftText, AppIcons.ball),
    'request.expired' => (const Color(0xFFFFF6D6), const Color(0xFF7A5A00), AppIcons.clock),
    _ when n.category == NotificationCategory.fund => (
      const Color(0xFFFDF0E6),
      const Color(0xFFA04800),
      AppIcons.wallet,
    ),
    _ => (AppColors.background, AppColors.text, AppIcons.bell),
  };
  return Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: AppIcon(icon, color: fg),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.n, required this.onTap});
  final NotificationDto n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    height: 1.4,
                    fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Fmt.ago(n.createdAt)} · ${n.body}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!n.read)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 6, left: 8),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
        ],
      ),
    ),
  );
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.n, required this.onTap});
  final NotificationDto n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        children: [
          Row(
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${Fmt.ago(n.createdAt)} · ${n.body}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      children: [
                        const TextSpan(text: 'Tự huỷ nếu không trả lời sau '),
                        TextSpan(
                          text: Fmt.remaining(
                            n.createdAt.add(const Duration(hours: 2)).difference(DateTime.now()),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Text(
                  'Xem & xác nhận',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
