import '../../../core/router/auth_redirect.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../team/team_providers.dart';
import '../data/matches_repository.dart';
import '../matches_providers.dart';
import 'match_widgets.dart';

/// Màn 35 · Xác nhận kết quả trận khi đội đối đã gửi tỉ số.
/// "Đúng, xác nhận" gọi POST result/confirm; "Sai tỉ số" mở bước 2 chỉnh tỉ số rồi gửi đề xuất lại
/// (POST result với tỉ số mới). Người ghi bàn của đội mình nhập ở màn Kết quả trận sau khi chốt.
class MatchConfirmScreen extends ConsumerStatefulWidget {
  const MatchConfirmScreen({
    super.key,
    required this.teamId,
    required this.matchId,
    required this.detail,
    required this.onPropose,
  });
  final String teamId;
  final String matchId;
  final MatchDetailDto detail;

  /// Gọi khi chuyển sang chế độ nhập lại tỉ số (màn cha dựng form đầy đủ).
  final VoidCallback onPropose;

  @override
  ConsumerState<MatchConfirmScreen> createState() => _MatchConfirmScreenState();
}

class _MatchConfirmScreenState extends ConsumerState<MatchConfirmScreen> {
  bool _busy = false;

  MatchDetailDto get _d => widget.detail;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await ref.read(matchesRepositoryProvider).confirm(widget.teamId, widget.matchId);
      if (!mounted) return;
      ref.invalidate(matchDetailProvider);
      ref.invalidate(honorsProvider);
      ref.invalidate(teamProfileProvider);
      ref.invalidate(fundSummaryProvider(widget.teamId));
      showToast(context, 'Đã xác nhận tỉ số', type: ToastType.success);
    } catch (e) {
      if (mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final iAmHome = d.homeTeam.id == d.myTeamId;
    final me = iAmHome ? d.homeTeam : d.awayTeam;
    final opp = iAmHome ? d.awayTeam : d.homeTeam;
    final h = d.homeScore ?? 0;
    final a = d.awayScore ?? 0;
    final fee = matchFee(
      pitchPrice: d.pitchPrice,
      ratioWin: d.ratioWin,
      ratioLose: d.ratioLose,
      home: h,
      away: a,
      iAmHome: iAmHome,
    );
    final myScore = iAmHome ? h : a;
    final oppScore = iAmHome ? a : h;
    final verdict = myScore == oppScore ? 'hoà' : (myScore > oppScore ? 'thắng' : 'thua');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ResultTopBar(
              title: 'Xác nhận kết quả trận',
              showBack: true,
              onLeading: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Tỉ số ${opp.name} gửi'.toUpperCase(),
                    style: AppText.display(26),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [Fmt.slot(d.startAt), ?d.location].join(' · '),
                    style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 14),
                  NoticeStrip(
                    icon: AppIcons.clock,
                    text:
                        '${opp.name} đã gửi tỉ số. Hãy xác nhận nếu đúng, hoặc đề xuất lại tỉ số bạn cho là đúng.',
                  ),
                  const SizedBox(height: 14),
                  ScorePanel(
                    info: '${opp.name} gửi',
                    left: ScoreSide(
                      name: d.homeTeam.name,
                      crestColor: d.homeTeam.crestColor,
                      score: h,
                    ),
                    right: ScoreSide(
                      name: d.awayTeam.name,
                      crestColor: d.awayTeam.crestColor,
                      score: a,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (fee != null)
                    _InfoRow(
                      label: 'Tiền sân theo kèo',
                      value: 'Bạn trả ${Fmt.money(fee)}'
                          '${myScore == oppScore ? ' (hoà, chia đôi)' : ' ($verdict ${verdict == 'thắng' ? d.ratioWin : d.ratioLose}%)'}',
                    ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => context.push(
                      '/report-team/${me.id}/${opp.id}?matchId=${widget.matchId}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      height: AppSizes.tapTarget,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            text: 'Có vấn đề khác với đội này? ',
                            style: TextStyle(fontSize: 14, color: AppColors.textDim),
                            children: [
                              TextSpan(
                                text: 'Báo cáo',
                                style: TextStyle(
                                  color: AppColors.lime,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ResultBottomBar(
              children: [
                LimeButton(
                  label: 'Đúng, xác nhận $h–$a',
                  loading: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
                GhostButton(
                  label: 'Sai tỉ số, đề xuất lại',
                  onPressed: _busy ? null : widget.onPropose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.group),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Wrapper route cho Màn 35 khi mở trực tiếp từ route.
class MatchConfirmRouteScreen extends ConsumerWidget {
  const MatchConfirmRouteScreen({super.key, required this.teamId, required this.matchId});
  final String teamId;
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(matchDetailProvider((teamId: teamId, matchId: matchId)));
    return AsyncView(
      value: detail,
      onRetry: () => ref.invalidate(matchDetailProvider((teamId: teamId, matchId: matchId))),
      data: (d) => MatchConfirmScreen(
        teamId: teamId,
        matchId: matchId,
        detail: d,
        onPropose: () => context.pushReplacement(Routes.matchResult(teamId, matchId)),
      ),
    );
  }
}
