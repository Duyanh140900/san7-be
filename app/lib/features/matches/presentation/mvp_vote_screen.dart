
import '../data/matches_repository.dart';
import '../../../core/api/api_error.dart';
import '../../../core/widgets/app_toast.dart';
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

final mvpVotesProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, MatchKey>(
  (ref, k) => ref.watch(matchesRepositoryProvider).mvpVotes(k.teamId, k.matchId),
);

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
  bool _saving = false;

  MatchKey get _key => (teamId: widget.teamId, matchId: widget.matchId);

  Future<void> _submitVote() async {
    if (_pick == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(matchesRepositoryProvider).castMvpVote(widget.teamId, widget.matchId, _pick!);
      if (!mounted) return;
      ref.invalidate(mvpVotesProvider(_key));
      setState(() => _voted = _pick);
      AppToast.success('Đã gửi phiếu bình chọn MVP!');
    } catch (e) {
      if (mounted) AppToast.error(ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
    final voteData = ref.watch(mvpVotesProvider(_key)).value;
    final candidates = (voteData?['candidates'] as List<dynamic>?) ?? [];
    final candidateVotes = {
      for (final item in candidates)
        if (item is Map<String, dynamic>)
          (item['userId'] as String? ?? ''): (item['votes'] as int? ?? 0)
    };
    if (voteData?['myVoteUserId'] case final String myVote when _voted == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _voted == null) setState(() { _voted = myVote; _pick ??= myVote; });
      });
    }
    final votes = [
      for (final (i, p) in players.indexed)
        candidateVotes.containsKey(p.userId)
            ? candidateVotes[p.userId]!
            : (_fakeVotes(i, p) + (p.userId == _voted ? 1 : 0))
    ];
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
          loading: _saving,
          onPressed: changed && !_saving ? _submitVote : null,
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
