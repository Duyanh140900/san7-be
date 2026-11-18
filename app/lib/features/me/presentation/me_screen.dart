import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/team_crest.dart';
import '../../posts/presentation/post_widgets.dart';
import '../data/account_repository.dart';
import '../data/me_repository.dart';
import '../me_providers.dart';

/// Màn 24 · Cá nhân & cài đặt.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return const Scaffold();
    final me = auth.me;
    final openPosts = ref.watch(myPostsProvider(PostStatus.open)).value?.items.length;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DetailHeader(
              backLabel: 'Bảng tin',
              trailing: LinkButton('Sửa', onTap: () => context.push(Routes.editProfile)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _Profile(me: me),
                  const SizedBox(height: 12),
                  _Stats(stats: me.stats),
                  const SizedBox(height: 16),
                  const SectionLabel('Đội của tôi'),
                  MeGroup(
                    children: [
                      for (final t in me.teams)
                        MeRow(
                          leading: TeamCrest(name: t.name, color: t.crestColor, width: 36),
                          title: t.name,
                          value: Labels.role(t.role),
                          onTap: () => context.go(Routes.team),
                        ),
                      MeRow(
                        title: 'Tạo hoặc tham gia đội khác',
                        accent: true,
                        onTap: () => context.push(Routes.addTeam),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Hoạt động'),
                  MeGroup(
                    children: [
                      MeRow(
                        leading: const ActivityIcon(AppIcons.chatBox, AppColors.lime),
                        title: 'Kèo của tôi',
                        value: openPosts == null ? null : '$openPosts đang mở',
                        onTap: () => context.push(Routes.myPosts),
                      ),
                      MeRow(
                        leading: const ActivityIcon(AppIcons.pin, AppColors.green),
                        title: 'Lịch sử đặt sân',
                        onTap: () => context.push(Routes.bookingHistory),
                      ),
                      MeRow(
                        leading: const ActivityIcon(AppIcons.wallet, AppColors.hot),
                        title: 'Quỹ của tôi',
                        onTap: () => context.go(Routes.teamFunds),
                      ),
                      MeRow(
                        leading: const ActivityIcon(AppIcons.trophy, AppColors.trophy),
                        title: 'Danh hiệu',
                        onTap: () => context.go(Routes.honors),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Thông báo'),
                  const _NotificationSwitches(),
                  const SizedBox(height: 16),
                  const SectionLabel('Mặc định'),
                  MeGroup(
                    children: [
                      MeRow(
                        title: 'Khu vực mặc định',
                        value: me.area ?? 'Chưa chọn',
                        onTap: () => context.push(Routes.editProfile),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  MeGroup(
                    children: [
                      MeRow(
                        title: 'Đăng xuất',
                        destructive: true,
                        onTap: () => _confirmSignOut(context, ref),
                      ),
                      MeRow(
                        title: 'Xoá tài khoản',
                        destructive: true,
                        onTap: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá tài khoản?'),
        content: const Text(
          'Tài khoản, thiết bị và thông tin cá nhân của bạn sẽ bị xoá vĩnh viễn và không thể khôi phục.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá vĩnh viễn', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      final err = ApiError.from(e);
      if (!context.mounted) return;
      if (err.statusCode == 409 || err.code == 'captain_must_transfer') {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Chưa thể xoá tài khoản'),
            content: const Text(
              'Vui lòng chuyển quyền Đội trưởng hoặc giải tán đội trước khi xoá tài khoản.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đã hiểu')),
            ],
          ),
        );
      } else {
        showToast(context, err.message, type: ToastType.error);
      }
    }
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.me});
  final MeDto me;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Avatar(name: me.name, url: me.avatarUrl, size: 76, border: AppColors.lime),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              me.name.toUpperCase(),
              style: AppText.display(30),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              Labels.playerLine(me.position, me.shirtNumber),
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Ô icon 30px bo 8 nền màu của dòng trong mục Hoạt động.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(this.icon, this.color, {super.key});
  final AppIcons icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    alignment: Alignment.center,
    child: AppIcon(icon, size: 18, color: AppColors.ink),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});
  final PlayerStatsDto stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Trận', stats.matches),
      ('Bàn', stats.goals),
      ('Kiến tạo', stats.assists),
      ('MVP', stats.mvps),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          for (final (label, v) in items)
            Expanded(
              child: Column(
                children: [
                  Text('${v.toInt()}', style: AppText.display(30, color: AppColors.lime)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Nhóm dòng trắng bo 14, ngăn bằng đường kẻ mảnh.
class MeGroup extends StatelessWidget {
  const MeGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 16, color: AppColors.divider),
          children[i],
        ],
      ],
    ),
  );
}

class MeRow extends StatelessWidget {
  const MeRow({
    super.key,
    required this.title,
    this.value,
    this.onTap,
    this.leading,
    this.destructive = false,
    this.accent = false,
  });
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? leading;
  final bool destructive;

  /// Chữ xanh chủ đạo, không có mũi tên (dòng hành động như "Tạo hoặc tham gia đội khác").
  final bool accent;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget + 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: destructive
                      ? AppColors.red
                      : accent
                      ? AppColors.primary
                      : AppColors.text,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (onTap != null && !destructive && !accent)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Text('›', style: TextStyle(fontSize: 20, color: AppColors.disabled)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationSwitches extends ConsumerWidget {
  const _NotificationSwitches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    return AsyncView(
      value: settings,
      onRetry: () => ref.invalidate(notificationSettingsProvider),
      data: (s) {
        Widget row(String title, bool value, UpdateNotificationSettingsDto Function(bool) patch) =>
            NotificationSwitchRow(
              title: title,
              value: value,
              onChanged: (v) async {
                try {
                  await ref.read(meRepositoryProvider).updateNotificationSettings(patch(v));
                  ref.invalidate(notificationSettingsProvider);
                } catch (e) {
                  if (context.mounted) {
                    showToast(context, ApiError.from(e).message, type: ToastType.error);
                  }
                }
              },
            );
        return MeGroup(
          children: [
            row(
              'Cập nhật trận đấu',
              s.matchUpdates,
              (v) => UpdateNotificationSettingsDto(matchUpdates: v),
            ),
            row(
              'Hoạt động của đội',
              s.teamActivity,
              (v) => UpdateNotificationSettingsDto(teamActivity: v),
            ),
            row('Cộng đồng', s.community, (v) => UpdateNotificationSettingsDto(community: v)),
          ],
        );
      },
    );
  }
}

class NotificationSwitchRow extends StatelessWidget {
  const NotificationSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
        Switch(value: value, onChanged: onChanged),
      ],
    ),
  );
}
