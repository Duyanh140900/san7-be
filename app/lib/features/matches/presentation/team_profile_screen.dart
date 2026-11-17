import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/team_crest.dart';
import '../../chat/presentation/chat_launcher.dart';
import '../../posts/presentation/post_widgets.dart';
import '../matches_providers.dart';

/// Màu và chữ của kết quả W/D/L.
(Color, String) outcomeStyle(String o) => switch (o) {
  'W' => (AppColors.green, 'T'),
  'L' => (AppColors.red, 'B'),
  _ => (const Color(0xFF8E8E93), 'H'),
};

/// Màn 22 · Hồ sơ đội (xem được đội khác): thành tích, uy tín, nhận xét, trận gần đây.
class TeamProfileScreen extends ConsumerWidget {
  const TeamProfileScreen({super.key, required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(teamProfileProvider(teamId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const DetailHeader(backLabel: 'Quay lại'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(teamProfileProvider(teamId).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    AsyncView(
                      value: profile,
                      onRetry: () => ref.invalidate(teamProfileProvider(teamId)),
                      data: (p) => _Body(profile: p),
                    ),
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SoftButton(
                        label: 'Nhắn tin',
                        onPressed: () => openChatWithTeam(context, ref, teamId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => context.push(Routes.postNew),
                        child: const Text('Mời đá kèo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});
  final TeamProfileDto profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final r = p.record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            TeamCrest(name: p.team.name, color: p.team.crestColor, width: 84),
            const SizedBox(height: 12),
            Text(
              p.team.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${p.team.area} · Trình độ ${Labels.level(p.team.level)} · '
              '${p.memberCount} thành viên · từ ${p.sinceYear}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  _Stat(
                    p.reputation == null ? '—' : Fmt.rating(p.reputation!),
                    'Uy tín (${p.reviewCount} lượt)',
                  ),
                  _Stat(p.onTimePercent == null ? '—' : '${p.onTimePercent}%', 'Đúng giờ'),
                  _Stat(p.fairplay == null ? '—' : Fmt.rating(p.fairplay!), 'Fair-play'),
                ],
              ),
              const Divider(height: 24, color: AppColors.divider),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.played == 0
                          ? 'Chưa có trận nào được xác nhận'
                          : '${r.played} trận · ${r.wins}T ${r.draws}H ${r.losses}B',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  for (final o in r.form) ...[const SizedBox(width: 5), _FormBox(o.toJson())],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đối thủ nhận xét',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (p.tags.isEmpty && p.reviews.isEmpty)
                const Text(
                  'Chưa có đánh giá nào.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              if (p.tags.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final t in p.tags) _TagCount(Labels.reviewTag(t.tag), t.count)],
                ),
              for (final rv in p.reviews) ...[
                const Divider(height: 24, color: AppColors.divider),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rv.fromTeam.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '★' * rv.reputation + '☆' * (5 - rv.reputation),
                      style: const TextStyle(color: AppColors.star, fontSize: 14),
                    ),
                  ],
                ),
                if (rv.comment != null) ...[
                  const SizedBox(height: 4),
                  Text(rv.comment!, style: const TextStyle(fontSize: 15, height: 1.4)),
                ],
              ],
            ],
          ),
        ),
        if (p.recentMatches.isNotEmpty) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trận gần đây',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                for (final m in p.recentMatches)
                  Container(
                    constraints: const BoxConstraints(minHeight: 50),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'vs ${m.opponent.name}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        Text(
                          Fmt.dayMonth(m.startAt),
                          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        ),
                        SizedBox(
                          width: 54,
                          child: Text(
                            '${m.goalsFor}–${m.goalsAgainst}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: m.outcome == RecentMatchDtoOutcome.w
                                  ? AppColors.greenSoftText
                                  : m.outcome == RecentMatchDtoOutcome.l
                                  ? AppColors.red
                                  : AppColors.text,
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
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _FormBox extends StatelessWidget {
  const _FormBox(this.outcome);
  final String outcome;

  @override
  Widget build(BuildContext context) {
    final (color, letter) = outcomeStyle(outcome);
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7)),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

class _TagCount extends StatelessWidget {
  const _TagCount(this.label, this.count);
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.greenSoftText,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(
            text: '$count',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}
