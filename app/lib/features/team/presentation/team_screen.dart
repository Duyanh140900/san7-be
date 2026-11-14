import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn 5 · Đội bóng. M0 chỉ hiện đội của tôi; thành tích, quỹ, lịch làm ở M1.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth is AuthSignedIn ? auth.me : null;
    final teams = me?.teams ?? const <MyTeamDto>[];

    return TabPage(
      title: 'Đội',
      actions: [
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Đăng xuất'),
        ),
      ],
      children: [
        if (teams.isEmpty)
          const ComingSoonCard(
            icon: AppIcons.team,
            title: 'Bạn chưa có đội',
            message: 'Tạo đội mới hoặc nhập mã mời đội trưởng gửi.',
          )
        else
          for (final t in teams) ...[_TeamCard(team: t), const SizedBox(height: 12)],
        if (teams.isEmpty) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push(Routes.onboardingTeam),
            child: const Text('Tạo hoặc tham gia đội'),
          ),
        ],
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team});
  final MyTeamDto team;

  @override
  Widget build(BuildContext context) {
    final pending = switch (team.status) {
      MemberStatusKnown(value: MemberStatusValue.pending) => true,
      _ => false,
    };
    final crest = Color(int.parse('FF${team.crestColor.substring(1)}', radix: 16));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: crest, borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Text(
              team.name.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${team.area} · ${Labels.level(team.level)} · ${Labels.role(team.role)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: const Text(
                'Chờ duyệt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB25E00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
