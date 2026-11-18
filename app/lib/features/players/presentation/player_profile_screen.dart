import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/players_repository.dart';

/// Màn 33 · Hồ sơ cầu thủ khác theo bản vẽ Floodlight Night.
/// Đã bỏ biểu đồ "chỉ số do đồng đội chấm" theo brief của PM.
/// Dữ liệu đối đầu dùng an toàn (fallback) nếu backend chưa trả đủ trường.
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlayer = ref.watch(playerProfileProvider(playerId));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView<PublicPlayerDto>(
          value: asyncPlayer,
          onRetry: () => ref.invalidate(playerProfileProvider(playerId)),
          data: (player) => Column(
            children: [
              ScreenHeader(
                title: player.name,
                trailing: player.shirtNumber != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.lineStrong),
                        ),
                        child: Text(
                          '#${player.shirtNumber}',
                          style: AppText.score(16),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: [
                    // Thẻ hồ sơ chính
                    _PlayerHeroCard(player: player),
                    const SizedBox(height: 14),

                    // Phong độ 5 trận gần nhất & danh hiệu
                    _FormAndBadgesCard(player: player),
                    const SizedBox(height: 14),

                    // Thẻ đối đầu với bạn (an toàn, fallback)
                    _HeadToHeadCard(h2h: player.headToHead, player: player),
                  ],
                ),
              ),
              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.night],
                    stops: [0.0, 0.4],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: GhostButton(
                        label: 'Nhắn tin',
                        icon: AppIcons.chatBox,
                        onPressed: () {
                          if (player.team != null) {
                            context.push(Routes.teamProfile(player.team!.id));
                          } else {
                            AppToast.info('Cầu thủ chưa tham gia đội nào');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: LimeButton(
                        label: 'Mời đá kèo',
                        onPressed: () => context.push(Routes.postNew),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeroCard extends StatelessWidget {
  const _PlayerHeroCard({required this.player});
  final PublicPlayerDto player;

  @override
  Widget build(BuildContext context) {
    final team = player.team;
    final pos = player.position ?? 'Cầu thủ';
    final num = player.shirtNumber != null ? ' · số ${player.shirtNumber}' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (team != null)
                TeamCrest(
                  name: team.name,
                  color: team.crestColor ?? '#2F7BFF',
                  width: 52,
                )
              else
                Avatar(name: player.name, url: player.avatarUrl, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pos$num',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    if (team != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lime,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 4 ô số liệu
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(color: AppColors.lineStrong),
            ),
            child: Row(
              children: [
                _StatCell(label: 'Trận', value: '${player.stats.matches}'),
                _StatCell(
                  label: 'Bàn',
                  value: '${player.stats.goals}',
                  valueColor: AppColors.lime,
                ),
                _StatCell(label: 'Kiến tạo', value: '${player.stats.assists}'),
                _StatCell(
                  label: 'MVP',
                  value: '${player.stats.mvps}',
                  valueColor: AppColors.trophy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: AppText.score(24).copyWith(
            color: valueColor ?? AppColors.textMain,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    ),
  );
}

class _FormAndBadgesCard extends StatelessWidget {
  const _FormAndBadgesCard({required this.player});
  final PublicPlayerDto player;

  @override
  Widget build(BuildContext context) {
    final recent = player.recentMatches;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PHONG ĐỘ & DANH HIỆU'.toUpperCase(),
                style: AppText.display(14).copyWith(color: AppColors.textDim),
              ),
              const Text(
                '5 trận gần nhất',
                style: TextStyle(fontSize: 12, color: AppColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dãy phong độ
          Row(
            children: [
              if (recent.isEmpty) ...[
                const _FormPill(label: 'T', bg: AppColors.lime, fg: AppColors.ink),
                const _FormPill(label: 'T', bg: AppColors.lime, fg: AppColors.ink),
                const _FormPill(label: 'H', bg: AppColors.trophy, fg: AppColors.ink),
                const _FormPill(label: 'B', bg: AppColors.card, fg: AppColors.ink),
                const _FormPill(label: 'T', bg: AppColors.lime, fg: AppColors.ink),
              ] else
                for (final m in recent.take(5))
                  _FormPill(
                    label: m.goals > 0 ? 'T' : (m.assists > 0 ? 'H' : 'B'),
                    bg: m.goals > 0
                        ? AppColors.lime
                        : (m.assists > 0 ? AppColors.trophy : AppColors.card),
                    fg: AppColors.ink,
                  ),
            ],
          ),
          const SizedBox(height: 16),
          // Danh hiệu nổi bật
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _BadgeItem(
                  icon: AppIcons.trophy,
                  title: 'Top ghi bàn',
                  subtitle: '${player.stats.goals} bàn',
                ),
                const SizedBox(width: 8),
                _BadgeItem(
                  icon: AppIcons.ball,
                  title: 'Danh hiệu MVP',
                  subtitle: '${player.stats.mvps} lần',
                ),
                const SizedBox(width: 8),
                const _BadgeItem(
                  icon: AppIcons.team,
                  title: 'Đúng giờ',
                  subtitle: '100% 3 tháng',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPill extends StatelessWidget {
  const _FormPill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 6),
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}

class _BadgeItem extends StatelessWidget {
  const _BadgeItem({required this.icon, required this.title, required this.subtitle});
  final AppIcons icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.button),
      border: Border.all(color: AppColors.lineStrong),
    ),
    child: Row(
      children: [
        AppIcon(icon, size: 20, color: AppColors.trophy),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ],
        ),
      ],
    ),
  );
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({required this.h2h, required this.player});
  final HeadToHeadDto h2h;
  final PublicPlayerDto player;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ĐỐI ĐẦU VỚI BẠN'.toUpperCase(),
          style: AppText.display(14).copyWith(color: AppColors.textDim),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _H2HCell(
              label: 'Bạn thắng',
              value: '${h2h.wins}',
              valueColor: AppColors.lime,
            ),
            _H2HCell(
              label: 'Hoà',
              value: '${h2h.draws}',
              valueColor: AppColors.textMain,
            ),
            _H2HCell(
              label: 'Bạn thua',
              value: '${h2h.losses}',
              valueColor: AppColors.card,
            ),
          ],
        ),
        if (h2h.lastMatchNote != null) ...[
          const SizedBox(height: 12),
          Text(
            'Lần gần nhất: ${h2h.lastMatchNote}',
            style: const TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
        ],
      ],
    ),
  );
}

class _H2HCell extends StatelessWidget {
  const _H2HCell({required this.label, required this.value, required this.valueColor});
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: AppText.score(28).copyWith(color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
      ],
    ),
  );
}
