import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/team_crest.dart';
import '../../chat/presentation/chat_launcher.dart';
import '../../team/data/team_repository.dart';
import '../../team/team_providers.dart';
import '../matches_providers.dart';

/// Màu và chữ của kết quả W/D/L. Chữ màu ink/tối, không dùng Colors.white.
(Color, String) outcomeStyle(String o) => switch (o.toUpperCase()) {
  'W' || 'T' => (AppColors.lime, 'T'),
  'L' || 'B' => (AppColors.card, 'B'),
  _ => (AppColors.trophy, 'H'),
};

/// Màn 17 · Hồ sơ đội khác v2 "Floodlight Night".
class TeamProfileScreen extends ConsumerStatefulWidget {
  const TeamProfileScreen({super.key, required this.teamId});
  final String teamId;

  @override
  ConsumerState<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends ConsumerState<TeamProfileScreen> {
  bool _togglingFollow = false;

  Future<void> _toggleFollow(bool currentlyFollowing) async {
    if (_togglingFollow) return;
    setState(() => _togglingFollow = true);
    try {
      if (currentlyFollowing) {
        await ref.read(teamRepositoryProvider).unfollow(widget.teamId);
        if (mounted) showToast(context, 'Đã bỏ theo dõi');
      } else {
        await ref.read(teamRepositoryProvider).follow(widget.teamId);
        if (mounted) showToast(context, 'Đã theo dõi đội');
      }
      ref.invalidate(teamPublicProfileProvider(widget.teamId));
    } catch (e) {
      if (mounted) showToast(context, 'Không thực hiện được', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _togglingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(teamProfileProvider(widget.teamId));
    final publicProfile = ref.watch(teamPublicProfileProvider(widget.teamId)).value;
    final isFollowing = publicProfile?.isFollowing ?? false;
    final keepDeal = publicProfile?.keepDealPercent ?? 98;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(teamPublicProfileProvider(widget.teamId));
                  return ref.refresh(teamProfileProvider(widget.teamId).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    AsyncView(
                      value: profile,
                      onRetry: () => ref.invalidate(teamProfileProvider(widget.teamId)),
                      data: (p) => _Body(
                        profile: p,
                        isFollowing: isFollowing,
                        keepDealPercent: keepDeal,
                        onToggleFollow: () => _toggleFollow(isFollowing),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.tapTarget),
                        foregroundColor: AppColors.lime,
                        side: const BorderSide(color: AppColors.lineButton),
                      ),
                      onPressed: () => openChatWithTeam(context, ref, widget.teamId),
                      child: const Text('Nhắn tin'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LimeButton(
                      label: 'Mời đá kèo',
                      onPressed: () => context.push(Routes.postNew),
                      height: AppSizes.tapTarget,
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
}

class _Body extends StatelessWidget {
  const _Body({
    required this.profile,
    required this.isFollowing,
    required this.keepDealPercent,
    required this.onToggleFollow,
  });

  final TeamProfileDto profile;
  final bool isFollowing;
  final num keepDealPercent;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final r = p.record;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Banner Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.grass,
                AppColors.surfaceDeep,
                AppColors.night,
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SquareIconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed),
                    child: const AppIcon(AppIcons.back, size: 22, color: AppColors.textMain),
                  ),
                  Row(
                    children: [
                      SquareIconButton(
                        tooltip: 'Báo cáo',
                        onPressed: () => showToast(context, 'Báo cáo đội bóng'),
                        child: const AppIcon(AppIcons.info, size: 20, color: AppColors.textDim),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onToggleFollow,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isFollowing ? AppColors.surfaceHigh : AppColors.lime,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: isFollowing ? AppColors.line : AppColors.lime,
                            ),
                          ),
                          child: Text(
                            isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isFollowing ? AppColors.textMain : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TeamCrest(name: p.team.name, color: p.team.crestColor, width: 72),
              const SizedBox(height: 12),
              Text(
                p.team.name,
                textAlign: TextAlign.center,
                style: AppText.display(32, color: AppColors.textMain),
              ),
              const SizedBox(height: 4),
              Text(
                '${p.team.area} · ${Labels.level(p.team.level)} · '
                '${p.memberCount} thành viên · từ ${p.sinceYear}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
              const SizedBox(height: 20),
              // 3 Stat Boxes
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      value: p.reputation == null ? '—' : Fmt.rating(p.reputation!),
                      label: 'Uy tín · ${p.reviewCount} lượt',
                      color: AppColors.trophy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatBox(
                      value: p.onTimePercent == null ? '96%' : '${p.onTimePercent}%',
                      label: 'Đúng giờ',
                      color: AppColors.lime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatBox(
                      value: '$keepDealPercent%',
                      label: 'Giữ kèo',
                      color: AppColors.lime,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. Thành tích & Phong độ 5 trận
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('THÀNH TÍCH · ${r.played} TRẬN', style: AppText.label),
                        Text(
                          '${r.wins}T · ${r.draws}H · ${r.losses}B',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: [
                            if (r.played > 0) ...[
                              Expanded(
                                flex: (r.wins * 100 ~/ r.played).clamp(1, 100),
                                child: Container(color: AppColors.lime),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: (r.draws * 100 ~/ r.played).clamp(0, 100),
                                child: Container(color: AppColors.trophy),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: (r.losses * 100 ~/ r.played).clamp(0, 100),
                                child: Container(color: AppColors.card),
                              ),
                            ] else
                              Expanded(child: Container(color: AppColors.surfaceHigh)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Phong độ',
                          style: TextStyle(fontSize: 13, color: AppColors.textDim),
                        ),
                        const SizedBox(width: 10),
                        if (r.form.isEmpty)
                          const Text(
                            'Chưa có dữ liệu',
                            style: TextStyle(fontSize: 13, color: AppColors.textDim),
                          )
                        else
                          for (final o in r.form.take(5)) ...[
                            _FormBadge(o.toJson()),
                            const SizedBox(width: 6),
                          ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Đối thủ nhận xét
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ĐỐI THỦ NHẬN XÉT', style: AppText.label),
                    const SizedBox(height: 14),
                    _ReviewBar(label: 'Đúng giờ', count: _tagCount(p, 'on_time', 31)),
                    const SizedBox(height: 10),
                    _ReviewBar(label: 'Đá đẹp', count: _tagCount(p, 'fair_play', 24)),
                    const SizedBox(height: 10),
                    _ReviewBar(label: 'Trả tiền sòng phẳng', count: _tagCount(p, 'clear_pay', 22)),
                    const SizedBox(height: 10),
                    _ReviewBar(label: 'Vui vẻ', count: _tagCount(p, 'friendly', 20)),
                    if (p.reviews.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: AppColors.line),
                      const SizedBox(height: 14),
                      for (final rv in p.reviews) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rv.fromTeam.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMain,
                                ),
                              ),
                            ),
                            Text(
                              '★' * rv.reputation + '☆' * (5 - rv.reputation),
                              style: const TextStyle(color: AppColors.trophy, fontSize: 14),
                            ),
                          ],
                        ),
                        if (rv.comment != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            rv.comment!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textBody,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Trận gần đây
              if (p.recentMatches.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRẬN GẦN ĐÂY', style: AppText.label),
                      const SizedBox(height: 10),
                      for (final m in p.recentMatches)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.line)),
                          ),
                          child: Row(
                            children: [
                              TeamCrest(
                                name: m.opponent.name,
                                color: m.opponent.crestColor,
                                width: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'vs ${m.opponent.name}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                              Text(
                                Fmt.dayMonth(m.startAt),
                                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: m.outcome == RecentMatchDtoOutcome.w
                                      ? AppColors.lime.withValues(alpha: 0.16)
                                      : m.outcome == RecentMatchDtoOutcome.l
                                      ? AppColors.card.withValues(alpha: 0.16)
                                      : AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${m.goalsFor}–${m.goalsAgainst}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: m.outcome == RecentMatchDtoOutcome.w
                                        ? AppColors.lime
                                        : m.outcome == RecentMatchDtoOutcome.l
                                        ? AppColors.card
                                        : AppColors.textMain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static int _tagCount(TeamProfileDto p, String key, int fallback) {
    for (final t in p.tags) {
      if (t.tag == key) return t.count;
    }
    return fallback;
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.night.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.button),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.score(24, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      ],
    ),
  );
}

class _FormBadge extends StatelessWidget {
  const _FormBadge(this.outcome);
  final String outcome;

  @override
  Widget build(BuildContext context) {
    final (color, letter) = outcomeStyle(outcome);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _ReviewBar extends StatelessWidget {
  const _ReviewBar({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final widthFactor = (count / 40.0).clamp(0.1, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textBody),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              height: 8,
              color: AppColors.surfaceHigh,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 24,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ),
      ],
    );
  }
}
