import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/system_state.dart';
import '../matches_providers.dart';
import 'match_widgets.dart';

/// Màn 39 · Bình chọn MVP sau trận.
/// TODO(backend): danh sách ứng viên lấy từ roster thật; số phiếu, phần trăm, hạn bình chọn và
/// việc gửi phiếu còn là DỮ LIỆU GIẢ (cục bộ) cho tới khi có API MvpVote
/// (GET/PUT /v1/teams/:teamId/matches/:matchId/mvp-votes).
class MvpVoteScreen extends ConsumerStatefulWidget {
  const MvpVoteScreen({super.key, required this.teamId, required this.matchId});
  final String teamId;
  final String matchId;

  @override
  ConsumerState<MvpVoteScreen> createState() => _MvpVoteScreenState();
}

class _MvpVoteScreenState extends ConsumerState<MvpVoteScreen> {
  String? _pick;
  String? _voted;

  MatchKey get _key => (teamId: widget.teamId, matchId: widget.matchId);

  /// Số phiếu giả, ổn định theo thứ tự trong roster.
  int _fakeVotes(int index, MatchPlayerDto p) => (p.goals * 2 + p.assists + 5 - index).clamp(0, 99);

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(matchDetailProvider(_key));
    final d = detail.value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ResultTopBar(
              title: 'Bình chọn MVP',
              showBack: true,
              onLeading: () => context.pop(),
            ),
            Expanded(
              child: d == null
                  ? Center(
                      child: AsyncView(
                        value: detail,
                        onRetry: () => ref.invalidate(matchDetailProvider(_key)),
                        data: (_) => const SizedBox.shrink(),
                      ),
                    )
                  : _body(d),
            ),
            if (d != null) _bottom(d),
          ],
        ),
      ),
    );
  }

  Widget _body(MatchDetailDto d) {
    final iAmHome = d.homeTeam.id == d.myTeamId;
    final me = iAmHome ? d.homeTeam : d.awayTeam;
    final opp = iAmHome ? d.awayTeam : d.homeTeam;
    final score = '${d.homeScore ?? 0}–${d.awayScore ?? 0}';
    final players = d.roster;
    final votes = [for (final (i, p) in players.indexed) _fakeVotes(i, p) + (p.userId == _voted ? 1 : 0)];
    final total = votes.fold(0, (a, b) => a + b);
    final deadline = d.endAt.add(const Duration(hours: 24));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: Text('Ai hay nhất?'.toUpperCase(), style: AppText.display(30))),
            Countdown(
              target: deadline,
              builder: (_, left) => MiniBadge(
                'Đóng sau ${formatCountdown(left)}',
                color: AppColors.trophy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceDeep,
            borderRadius: BorderRadius.circular(AppRadius.group),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${me.name} vs ${opp.name} · ${Fmt.weekday(d.startAt)} ${Fmt.dayMonth(d.startAt)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                ),
              ),
              Text(score, style: AppText.score(28)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        NoticeStrip(
          icon: AppIcons.info,
          color: AppColors.textMuted,
          text: _voted == null
              ? 'Chọn một đồng đội để bình chọn. Bạn đổi phiếu được tới khi hết hạn.'
              : 'Bạn đã bình chọn. Có thể đổi phiếu tới khi hết hạn.',
        ),
        const SizedBox(height: 16),
        if (players.isEmpty)
          const EmptyState(message: 'Chưa có danh sách cầu thủ của trận này.', compact: true)
        else
          for (final (i, p) in players.indexed)
            _Candidate(
              player: p,
              votes: votes[i],
              pct: total == 0 ? 0 : (votes[i] * 100 / total).round(),
              selected: _pick == p.userId,
              voted: _voted == p.userId,
              onTap: () => setState(() => _pick = p.userId),
            ),
      ],
    );
  }

  Widget _bottom(MatchDetailDto d) {
    final changed = _pick != null && _pick != _voted;
    final label = _voted == null ? 'Bình chọn' : 'Đổi phiếu';
    return ResultBottomBar(
      children: [
        LimeButton(
          label: label,
          onPressed: changed ? () => setState(() => _voted = _pick) : null,
        ),
      ],
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.player,
    required this.votes,
    required this.pct,
    required this.selected,
    required this.voted,
    required this.onTap,
  });
  final MatchPlayerDto player;
  final int votes;
  final int pct;
  final bool selected;
  final bool voted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stat = [
      if (player.goals > 0) '${player.goals} bàn',
      if (player.assists > 0) '${player.assists} kiến tạo',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${player.name}, $pct%, $votes phiếu',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.group),
              border: Border.all(color: selected ? AppColors.lime : AppColors.line, width: selected ? 1.5 : 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(name: player.name, url: player.avatarUrl, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                          if (stat.isNotEmpty)
                            Text(
                              stat,
                              style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$pct%', style: AppText.score(24, color: selected ? AppColors.lime : AppColors.textMain)),
                        Text('$votes phiếu', style: const TextStyle(fontSize: 11, color: AppColors.textDim)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    color: voted || selected ? AppColors.lime : AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
