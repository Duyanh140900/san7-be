import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../realtime/realtime_client.dart';
import '../router/auth_redirect.dart';
import '../theme/tokens.dart';
import 'app_icon.dart';

/// Khung có thanh tab 5 mục: Bảng tin, Đặt sân, [+ Đăng kèo], Đội, Bảng vàng.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Giữ kết nối realtime khi đang ở trong app
    ref.watch(teamRealtimeSyncProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppTabBar(
        currentBranch: shell.currentIndex,
        onBranch: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        onCreatePost: () => context.push(Routes.postNew),
      ),
    );
  }
}

class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.currentBranch,
    required this.onBranch,
    required this.onCreatePost,
  });

  final int currentBranch;
  final ValueChanged<int> onBranch;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 6, 8, bottomInset > 0 ? bottomInset : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Tab(
            icon: AppIcons.home,
            label: 'Bảng tin',
            selected: currentBranch == 0,
            onTap: () => onBranch(0),
          ),
          _Tab(
            icon: AppIcons.pin,
            label: 'Đặt sân',
            selected: currentBranch == 1,
            onTap: () => onBranch(1),
          ),
          _CreateButton(onTap: onCreatePost),
          _Tab(
            icon: AppIcons.team,
            label: 'Đội',
            selected: currentBranch == 2,
            onTap: () => onBranch(2),
          ),
          _Tab(
            icon: AppIcons.trophy,
            label: 'Bảng vàng',
            selected: currentBranch == 3,
            onTap: () => onBranch(3),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppIcons icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 60, minHeight: AppSizes.tapTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Đăng kèo',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 60,
          height: AppSizes.tapTarget,
          child: Center(
            child: Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.plus, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
