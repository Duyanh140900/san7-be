import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../chat/presentation/chat_entry_row.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../posts/presentation/post_widgets.dart';
import '../../team/team_providers.dart';
import '../data/matches_repository.dart';
import '../matches_providers.dart';

/// Màn 17 · Kết quả trận và đánh giá: tỉ số, ghi bàn, kiến tạo, cầu thủ hay nhất, đánh giá đối thủ.
class MatchResultScreen extends ConsumerStatefulWidget {
  const MatchResultScreen({super.key, required this.teamId, required this.matchId});
  final String teamId;
  final String matchId;

  @override
  ConsumerState<MatchResultScreen> createState() => _MatchResultScreenState();
}

class _MatchResultScreenState extends ConsumerState<MatchResultScreen> {
  int _home = 0;
  int _away = 0;
  final _goals = <String, int>{};
  final _assists = <String, int>{};
  String? _mvp;
  int _rep = 0;
  int _fair = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  MatchKey get _key => (teamId: widget.teamId, matchId: widget.matchId);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Điền sẵn từ dữ liệu server một lần (tỉ số, số liệu cầu thủ, đánh giá đã gửi).
  void _seed(MatchDetailDto d) {
    _seeded = true;
    _home = d.homeScore ?? 0;
    _away = d.awayScore ?? 0;
    for (final p in d.roster) {
      if (p.goals > 0) _goals[p.userId] = p.goals;
      if (p.assists > 0) _assists[p.userId] = p.assists;
      if (p.mvp) _mvp = p.userId;
    }
    final r = d.myReview;
    if (r != null) {
      _rep = r.reputation;
      _fair = r.fairplay;
      _tags.addAll(r.tags);
      _comment.text = r.comment ?? '';
    }
  }

  bool _iAmHome(MatchDetailDto d) => d.homeTeam.id == d.myTeamId;
  int _myScore(MatchDetailDto d) => _iAmHome(d) ? _home : _away;
  int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

  /// Tỉ số của đội mình nhỏ đi dưới số đã ghi thì xoá số đã ghi (khớp backend).
  void _clamp(MatchDetailDto d) {
    final s = _myScore(d);
    if (_sum(_goals) > s) _goals.clear();
    if (_sum(_assists) > s) _assists.clear();
  }

  void _score(MatchDetailDto d, {required bool home, required int delta}) {
    setState(() {
      if (home) {
        _home = (_home + delta).clamp(0, 99);
      } else {
        _away = (_away + delta).clamp(0, 99);
      }
      _clamp(d);
    });
  }

  /// Chạm chip: 0 → 1 → 2 … tới khi hết số bàn của đội rồi về 0.
  void _cycle(Map<String, int> m, String id, int cap) {
    final cur = m[id] ?? 0;
    final others = _sum(m) - cur;
    final next = cur + 1;
    setState(() {
      if (others + next > cap) {
        m.remove(id);
      } else {
        m[id] = next;
      }
    });
  }

  Future<void> _submit(MatchDetailDto d) async {
    setState(() => _saving = true);
    final repo = ref.read(matchesRepositoryProvider);
    try {
      final sameAsReported = d.homeScore == _home && d.awayScore == _away;
      final state = d.resultState;
      if (d.canReport) {
        if (state == MatchDetailDtoResultState.awaitingMe && sameAsReported) {
          await repo.confirm(widget.teamId, widget.matchId);
        } else if (!(state == MatchDetailDtoResultState.awaitingOpponent && sameAsReported)) {
          await repo.setResult(widget.teamId, widget.matchId, _home, _away);
        }
      }
      if (d.canEdit) {
        final ids = {for (final p in d.roster) p.userId};
        await repo.setStats(
          widget.teamId,
          widget.matchId,
          players: [
            for (final p in d.roster)
              if ((_goals[p.userId] ?? 0) > 0 || (_assists[p.userId] ?? 0) > 0)
                PlayerStatInput(
                  userId: p.userId,
                  goals: _goals[p.userId] ?? 0,
                  assists: _assists[p.userId] ?? 0,
                ),
          ],
          mvpUserId: _mvp != null && ids.contains(_mvp) ? _mvp : null,
        );
        if (_rep > 0 && _fair > 0) {
          await repo.review(
            widget.teamId,
            widget.matchId,
            SubmitReviewDto(
              reputation: _rep,
              fairplay: _fair,
              tags: [
                for (final t in Labels.reviewTags)
                  if (_tags.contains(t.$1.value)) SubmitReviewDtoTagsItemKnown(t.$1),
              ],
              comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            ),
          );
        }
      }
      if (!mounted) return;
      ref.invalidate(matchDetailProvider);
      ref.invalidate(honorsProvider);
      ref.invalidate(teamProfileProvider);
      ref.invalidate(fundSummaryProvider(widget.teamId));
      ref.invalidate(upcomingEventsProvider(widget.teamId));
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
      showToast(context, 'Đã lưu kết quả trận', type: ToastType.success);
      context.pop();
    } catch (e) {
      if (mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
      // Có bước đã thành công (vd tỉ số): tải lại để màn phản ánh đúng trạng thái
      ref.invalidate(matchDetailProvider(_key));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(matchDetailProvider(_key));
    final d = detail.value;
    if (d != null && !_seeded) _seed(d);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                children: [
                  LinkButton('Để sau', onTap: () => context.pop()),
                  const Expanded(
                    child: Text(
                      'Kết quả trận',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
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
            if (d != null && d.canEdit) _bottom(d),
          ],
        ),
      ),
    );
  }

  Widget _bottom(MatchDetailDto d) {
    final same = d.homeScore == _home && d.awayScore == _away;
    final confirming = d.resultState == MatchDetailDtoResultState.awaitingMe && same;
    final label = d.resultState == MatchDetailDtoResultState.confirmed
        ? 'Lưu thống kê & đánh giá'
        : confirming
        ? 'Xác nhận tỉ số $_home – $_away'
        : 'Gửi kết quả';
    return BottomActionBar(
      children: [
        FilledButton(
          onPressed: _saving ? null : () => _submit(d),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(label),
        ),
      ],
    );
  }

  Widget _body(MatchDetailDto d) {
    final iAmHome = _iAmHome(d);
    final opp = iAmHome ? d.awayTeam : d.homeTeam;
    final myScore = _myScore(d);
    final fee = matchFee(
      pitchPrice: d.pitchPrice,
      ratioWin: d.ratioWin,
      ratioLose: d.ratioLose,
      home: _home,
      away: _away,
      iAmHome: iAmHome,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _banner(d, opp),
        ChatEntryRow(teamId: widget.teamId, matchId: widget.matchId),
        const SizedBox(height: 12),
        _ScoreCard(
          detail: d,
          home: _home,
          away: _away,
          editable: d.canReport,
          onChange: (home, delta) => _score(d, home: home, delta: delta),
        ),
        if (d.canEdit) ...[
          const SizedBox(height: 20),
          FormCaption('Ghi bàn · $myScore bàn'),
          _chips(d, _goals, myScore),
          const SizedBox(height: 20),
          const FormCaption('Kiến tạo'),
          _chips(d, _assists, myScore),
          const SizedBox(height: 20),
          const FormCaption('Cầu thủ hay nhất'),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in d.roster)
                  _MvpChip(
                    player: p,
                    selected: _mvp == p.userId,
                    onTap: () => setState(() => _mvp = _mvp == p.userId ? null : p.userId),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FormCaption('Đánh giá ${opp.name}'),
          _reviewCard(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _footer(d, opp, fee),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
            ),
          ),
        ],
      ],
    );
  }

  String _footer(MatchDetailDto d, TeamBriefDto opp, int? fee) {
    if (d.resultState == MatchDetailDtoResultState.confirmed) {
      return d.myFee == null
          ? 'Thống kê và đánh giá sửa lại được. Điểm uy tín của đội đối thủ tự cập nhật.'
          : 'Phần tiền sân của đội bạn (${Fmt.money(d.myFee!)}) đã được trừ vào quỹ.';
    }
    final feeText = fee == null
        ? ''
        : '; phần tiền sân của đội bạn (${Fmt.money(fee)}) được trừ vào quỹ';
    return '${opp.name} sẽ xác nhận tỉ số. Khi khớp, thành tích, vua phá lưới và điểm uy tín '
        'tự cập nhật$feeText.';
  }

  Widget _banner(MatchDetailDto d, TeamBriefDto opp) {
    final h = d.homeScore;
    final a = d.awayScore;
    final (BannerTone, String)? b = switch (d.resultState) {
      _ when !d.ended => (
        BannerTone.neutral,
        'Trận chưa kết thúc. Quay lại sau giờ đá để nhập kết quả.',
      ),
      MatchDetailDtoResultState.awaitingOpponent => (
        BannerTone.waiting,
        'Đã gửi tỉ số $h – $a. Đang chờ ${opp.name} xác nhận.',
      ),
      MatchDetailDtoResultState.awaitingMe => (
        BannerTone.waiting,
        '${opp.name} đã nhập $h – $a. Xác nhận nếu đúng, hoặc sửa tỉ số rồi gửi lại.',
      ),
      MatchDetailDtoResultState.confirmed => (
        BannerTone.success,
        'Tỉ số $h – $a đã được hai đội xác nhận.',
      ),
      _ when !d.canEdit => (BannerTone.neutral, 'Chỉ đội trưởng hoặc phó đội nhập kết quả.'),
      _ => null,
    };
    if (b == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StatusBanner(tone: b.$1, child: Text(b.$2)),
    );
  }

  Widget _chips(MatchDetailDto d, Map<String, int> m, int cap) => SizedBox(
    height: 46,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final p in d.roster)
          _PlayerChip(
            player: p,
            count: m[p.userId] ?? 0,
            onTap: cap == 0 ? null : () => _cycle(m, p.userId, cap),
          ),
      ],
    ),
  );

  Widget _reviewCard() => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StarRow(
          label: 'Uy tín, đúng giờ',
          value: _rep,
          onChanged: (v) => setState(() => _rep = v),
        ),
        const SizedBox(height: 6),
        _StarRow(label: 'Fair-play', value: _fair, onChanged: (v) => setState(() => _fair = v)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in Labels.reviewTags)
              _TagChip(
                label: t.$2,
                selected: _tags.contains(t.$1.value),
                onTap: () => setState(
                  () =>
                      _tags.contains(t.$1.value) ? _tags.remove(t.$1.value) : _tags.add(t.$1.value),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _comment,
          maxLength: 200,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Nhận xét (không bắt buộc), hiện trên hồ sơ đội',
            counterText: '',
            border: InputBorder.none,
          ),
        ),
        if (_rep == 0 || _fair == 0)
          const Text(
            'Chấm cả hai mục sao để gửi đánh giá.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
      ],
    ),
  );
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.detail,
    required this.home,
    required this.away,
    required this.editable,
    required this.onChange,
  });
  final MatchDetailDto detail;
  final int home;
  final int away;
  final bool editable;
  final void Function(bool home, int delta) onChange;

  @override
  Widget build(BuildContext context) {
    Widget side(TeamBriefDto t, int score, bool isHome) => Expanded(
      child: Column(
        children: [
          Text(
            t.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 52,
              height: 1,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (editable) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Step('−', 'Bớt bàn ${t.name}', () => onChange(isHome, -1)),
                const SizedBox(width: 10),
                _Step('+', 'Thêm bàn ${t.name}', () => onChange(isHome, 1)),
              ],
            ),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          Text(
            [Fmt.slot(detail.startAt), ?detail.location].join(' · '),
            style: const TextStyle(fontSize: 13, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              side(detail.homeTeam, home, true),
              const Padding(
                padding: EdgeInsets.only(top: 34),
                child: Text('–', style: TextStyle(fontSize: 32, color: AppColors.disabled)),
              ),
              side(detail.awayTeam, away, false),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.label, this.semantic, this.onTap);
  final String label;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Color(0xFF3A3A3C), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 22, color: Colors.white)),
      ),
    ),
  );
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.player, required this.count, required this.onTap});
  final MatchPlayerDto player;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = count > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: on,
        label: '${player.name}${on ? ', $count' : ''}',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: on ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: on ? AppColors.primary : AppColors.pillBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(name: player.name, url: player.avatarUrl, size: 32),
                const SizedBox(width: 8),
                Text(player.name, style: const TextStyle(fontSize: 14)),
                if (on) ...[
                  const SizedBox(width: 6),
                  Text(
                    '×$count',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primarySoftText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MvpChip extends StatelessWidget {
  const _MvpChip({required this.player, required this.selected, required this.onTap});
  final MatchPlayerDto player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Semantics(
      button: true,
      selected: selected,
      label: 'Cầu thủ hay nhất: ${player.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 76,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldSoft : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.gold : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Avatar(name: player.name, url: player.avatarUrl, size: 48),
              const SizedBox(height: 6),
              Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
      for (var n = 1; n <= 5; n++)
        Semantics(
          button: true,
          label: '$n sao',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onChanged(n),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 34,
              height: 40,
              child: Icon(
                Icons.star_rounded,
                size: 28,
                color: n <= value ? AppColors.star : AppColors.border,
              ),
            ),
          ),
        ),
    ],
  );
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.greenSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.greenSoftText : AppColors.pillBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.greenSoftText : AppColors.text,
          ),
        ),
      ),
    ),
  );
}
