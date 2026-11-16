import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/team_crest.dart';
import '../posts_providers.dart';
import 'post_widgets.dart';

enum _Sort {
  fit('Phù hợp nhất'),
  early('Đăng ký sớm'),
  experienced('Đá nhiều nhất');

  const _Sort(this.label);
  final String label;
}

int _levelIndex(TeamLevel l) => switch (l) {
  TeamLevelKnown(:final value) => Labels.levels.indexWhere((e) => e.$1 == value),
  _ => 3,
};

/// Màn 11 · So sánh các đội nhận kèo. Uy tín, đúng giờ, khoảng cách có từ M3–M4.
class CompareRequestsScreen extends ConsumerStatefulWidget {
  const CompareRequestsScreen({super.key, required this.teamId, required this.postId});
  final String teamId;
  final String postId;

  @override
  ConsumerState<CompareRequestsScreen> createState() => _CompareRequestsScreenState();
}

class _CompareRequestsScreenState extends ConsumerState<CompareRequestsScreen> {
  _Sort _sort = _Sort.fit;

  List<MatchRequestDto> _sorted(List<MatchRequestDto> list, PostDto post) {
    final postLevel = _levelIndex(post.level);
    int fit(MatchRequestDto r) =>
        (_levelIndex(r.team.level) - postLevel).abs() * 10 + (r.ratioWin == null ? 0 : 5);
    final out = [...list];
    switch (_sort) {
      case _Sort.fit:
        out.sort((a, b) {
          final c = fit(a).compareTo(fit(b));
          return c != 0 ? c : b.team.matchesPlayed.compareTo(a.team.matchesPlayed);
        });
      case _Sort.early:
        out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _Sort.experienced:
        out.sort((a, b) => b.team.matchesPlayed.compareTo(a.team.matchesPlayed));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final key = (teamId: widget.teamId, postId: widget.postId);
    final requests = ref.watch(postRequestsProvider(key));
    final post = ref.watch(postDetailProvider(widget.postId));
    final count = requests.value?.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(
              backLabel: 'Quay lại',
              title: count == null ? 'So sánh' : 'So sánh $count đội',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(postRequestsProvider(key).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    AsyncView(
                      value: post,
                      data: (p) => AsyncView(
                        value: requests,
                        onRetry: () => ref.invalidate(postRequestsProvider(key)),
                        data: (list) => list.isEmpty
                            ? const AppCard(
                                child: Text(
                                  'Không còn đội nào đang chờ. Các yêu cầu có thể đã hết hạn.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : _Body(
                                post: p.post,
                                requests: _sorted(list, p.post),
                                ownerTeamId: widget.teamId,
                                sort: _sort,
                                onSort: (s) => setState(() => _sort = s),
                              ),
                      ),
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

class _Body extends StatelessWidget {
  const _Body({
    required this.post,
    required this.requests,
    required this.ownerTeamId,
    required this.sort,
    required this.onSort,
  });
  final PostDto post;
  final List<MatchRequestDto> requests;
  final String ownerTeamId;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;

  @override
  Widget build(BuildContext context) {
    final soonest = requests.map((r) => r.expiresAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final summary = [
      'Kèo ${Fmt.slot(post.startAt)}',
      ?post.pitchName,
      Labels.level(post.level),
      ?Labels.ratio(post.ratioWin, post.ratioLose, post.deal),
      'sớm nhất tự huỷ sau ${Fmt.remaining(soonest.difference(DateTime.now()))}',
    ].join(' · ');

    // Giá trị tốt nhất ở từng tiêu chí
    final postLevel = _levelIndex(post.level);
    final bestLevel = requests
        .map((r) => (_levelIndex(r.team.level) - postLevel).abs())
        .reduce((a, b) => a < b ? a : b);
    final bestRep = requests
        .map((r) => r.team.reputation)
        .whereType<num>()
        .fold<num?>(null, (a, b) => a == null || b > a ? b : a);
    final bestOnTime = requests
        .map((r) => r.team.onTimePercent)
        .whereType<int>()
        .fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    final bestPlayed = requests.map((r) => r.team.matchesPlayed).reduce((a, b) => a > b ? a : b);
    final bestPeople = requests.map((r) => r.peopleCount).reduce((a, b) => a > b ? a : b);

    final rows = <(String, List<(String, bool)>)>[
      (
        'Trình độ',
        [
          for (final r in requests)
            (
              Labels.level(r.team.level),
              (_levelIndex(r.team.level) - postLevel).abs() == bestLevel,
            ),
        ],
      ),
      (
        'Đã đá',
        [
          for (final r in requests)
            ('${r.team.matchesPlayed} trận', bestPlayed > 0 && r.team.matchesPlayed == bestPlayed),
        ],
      ),
      (
        'Uy tín',
        [
          for (final r in requests)
            (
              r.team.reputation == null ? '—' : Fmt.rating(r.team.reputation!),
              r.team.reputation != null && r.team.reputation == bestRep,
            ),
        ],
      ),
      (
        'Đúng giờ',
        [
          for (final r in requests)
            (
              r.team.onTimePercent == null ? '—' : '${r.team.onTimePercent}%',
              r.team.onTimePercent != null && r.team.onTimePercent == bestOnTime,
            ),
        ],
      ),
      (
        'Đối đầu',
        [
          for (final r in requests)
            (
              r.team.headToHead == 0
                  ? 'Chưa gặp'
                  : '${r.team.h2hOwnerWins}T · '
                        '${r.team.headToHead - r.team.h2hOwnerWins - r.team.h2hOwnerLosses}H · '
                        '${r.team.h2hOwnerLosses}B',
              false,
            ),
        ],
      ),
      ('Số người', [for (final r in requests) ('${r.peopleCount}', r.peopleCount == bestPeople)]),
      if (post.type == PostType.findOpponent && post.ratioWin != null)
        (
          'Tỷ lệ',
          [
            for (final r in requests)
              r.ratioWin == null ? ('Đồng ý', true) : ('${r.ratioWin} – ${r.ratioLose}', false),
          ],
        ),
      ('Thành viên', [for (final r in requests) ('${r.team.memberCount}', false)]),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            summary,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final s in _Sort.values)
                FilterPill(label: s.label, selected: s == sort, onTap: () => onSort(s)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Table(
          requests: requests,
          rows: rows,
          ownerTeamId: ownerTeamId,
          highlightFirst: sort == _Sort.fit,
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            SizedBox(width: 4),
            _Dot(),
            SizedBox(width: 6),
            Text(
              'Tốt nhất ở tiêu chí đó',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (requests.any((r) => r.message != null)) ...[
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Lời nhắn', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          for (final r in requests)
            if (r.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TeamAvatar(name: r.team.name, color: r.team.crestColor, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.team.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(r.message!, style: const TextStyle(fontSize: 15, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        const SizedBox(height: 14),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Khi bạn chọn một đội, các đội còn lại được báo là kèo đã có đối.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.requests,
    required this.rows,
    required this.ownerTeamId,
    required this.highlightFirst,
  });
  final List<MatchRequestDto> requests;
  final List<(String, List<(String, bool)>)> rows;
  final String ownerTeamId;
  final bool highlightFirst;

  static const _labelW = 96.0;
  static const _hl = AppColors.primaryTint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 3 đội vừa màn; nhiều hơn thì cuộn ngang
        final colW = ((c.maxWidth - _labelW) / requests.length.clamp(1, 3)).floorToDouble();
        Widget cell(Widget child, {required int col, double h = 46, bool border = true}) =>
            Container(
              width: colW,
              height: h,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: highlightFirst && col == 0 ? _hl : null,
                border: border ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
              ),
              child: child,
            );
        Widget label(String text, {double h = 46, bool border = true}) => Container(
          width: _labelW,
          height: h,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: border ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
          ),
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            color: AppColors.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    label('', h: 104),
                    for (final r in rows) label(r.$1),
                    label('', h: 60, border: false),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (i, req) in requests.indexed)
                          Column(
                            children: [
                              cell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TeamCrest(
                                      name: req.team.name,
                                      color: req.team.crestColor,
                                      width: 40,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      req.team.name,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (highlightFirst && i == 0)
                                      const Text(
                                        'Phù hợp nhất',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primarySoftText,
                                        ),
                                      ),
                                  ],
                                ),
                                col: i,
                                h: 104,
                              ),
                              for (final row in rows)
                                cell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          row.$2[i].$1,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: row.$2[i].$2
                                                ? AppColors.greenSoftText
                                                : AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (row.$2[i].$2) ...[const SizedBox(width: 5), const _Dot()],
                                    ],
                                  ),
                                  col: i,
                                ),
                              cell(
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: highlightFirst && i == 0
                                          ? AppColors.primary
                                          : AppColors.background,
                                      foregroundColor: highlightFirst && i == 0
                                          ? Colors.white
                                          : AppColors.primary,
                                      minimumSize: const Size.fromHeight(38),
                                    ),
                                    onPressed: () =>
                                        context.push(Routes.request(ownerTeamId, req.id)),
                                    child: const Text('Chọn'),
                                  ),
                                ),
                                col: i,
                                h: 60,
                                border: false,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(color: AppColors.greenBright, shape: BoxShape.circle),
  );
}
