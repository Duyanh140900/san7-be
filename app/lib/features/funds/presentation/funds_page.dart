import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../team/presentation/team_page_scaffold.dart';
import '../../team/team_providers.dart';
import 'add_fund_tx_screen.dart';
import 'fund_style.dart';
import 'fund_widgets.dart';

/// Tab Đội · Quỹ (bản vẽ 22).
class FundsPage extends ConsumerWidget {
  const FundsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const SizedBox.shrink();
    final team = ref.watch(teamDetailProvider(teamId));
    final summary = ref.watch(fundSummaryProvider(teamId));
    final canManage = team.value?.myRole.canManageFunds ?? false;
    final month = Fmt.vn(DateTime.now()).month;
    final auth = ref.watch(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;

    return TeamPageScaffold(
      section: TeamSection.funds,
      onRefresh: () async {
        ref.invalidate(fundSummaryProvider(teamId));
        await ref.read(fundSummaryProvider(teamId).future);
      },
      header: TeamTitleHeader(title: 'Quỹ đội', trailing: team.value?.name),
      children: [
        AsyncView<FundSummaryDto>(
          value: summary,
          onRetry: () => ref.invalidate(fundSummaryProvider(teamId)),
          data: (s) => Column(
            children: [
              _BalanceCard(summary: s, month: month),
              const SizedBox(height: 14),
              _Actions(canManage: canManage, dues: s.dues),
              if (s.dues != null) ...[
                const SizedBox(height: 14),
                _DuesCard(dues: s.dues!, canManage: canManage, myId: myId),
              ],
              const SizedBox(height: 14),
              _RecentCard(teamId: teamId, recent: s.recent, canManage: canManage),
            ],
          ),
        ),
      ],
    );
  }
}

/// Khối vàng "SỐ DƯ HIỆN TẠI" + thu/chi tháng.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.month});
  final FundSummaryDto summary;
  final int month;

  @override
  Widget build(BuildContext context) {
    Widget box(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FundStyle.goldInk.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FundStyle.goldInk,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FundStyle.goldInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: FundStyle.goldGradient,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SỐ DƯ HIỆN TẠI',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: FundStyle.goldInk,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(summary.balance),
              style: AppText.display(46, color: FundStyle.goldInk).copyWith(
                fontStyle: FontStyle.normal,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              box('Thu tháng $month', '+${Fmt.money(summary.monthIncome)}'),
              const SizedBox(width: 10),
              box('Chi tháng $month', '−${Fmt.money(summary.monthExpense)}'),
            ],
          ),
          if (summary.unpaidFines > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Tiền phạt chưa nộp: ${Fmt.money(summary.unpaidFines)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: FundStyle.goldInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Thêm khoản" (lime) + "Nhắc đóng quỹ" cho thủ quỹ/đội trưởng; thành viên thường chỉ có "Đóng quỹ".
class _Actions extends StatelessWidget {
  const _Actions({required this.canManage, required this.dues});
  final bool canManage;
  final DuesProgressDto? dues;

  @override
  Widget build(BuildContext context) {
    Widget button(
      String label,
      AppIcons icon,
      VoidCallback onTap, {
      required Color bg,
      required Color fg,
      bool outlined = false,
    }) => Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.button),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: outlined
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    border: Border.all(color: AppColors.lineStrong),
                  )
                : null,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!canManage) {
      if (dues == null) return const SizedBox.shrink();
      return Row(
        children: [
          button(
            'Đóng quỹ',
            AppIcons.wallet,
            () => context.push(Routes.teamFundPay),
            bg: AppColors.lime,
            fg: AppColors.ink,
          ),
        ],
      );
    }
    return Row(
      children: [
        button(
          'Thêm khoản',
          AppIcons.plus,
          () => context.push(Routes.teamFundNew),
          bg: AppColors.lime,
          fg: AppColors.ink,
        ),
        const SizedBox(width: 10),
        button(
          'Nhắc đóng quỹ',
          AppIcons.bell,
          () => showToast(context, 'Nhắc đóng quỹ qua thông báo đẩy sẽ có ở bản sau.'),
          bg: AppColors.surfaceHigh,
          fg: AppColors.textMain,
          outlined: true,
        ),
      ],
    );
  }
}

/// Vòng tiến độ đóng quỹ.
class _Ring extends CustomPainter {
  _Ring(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 8.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(w / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = AppColors.surfaceHigh;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = AppColors.lime;
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    if (value > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value;
}

class _DuesCard extends StatelessWidget {
  const _DuesCard({required this.dues, required this.canManage, required this.myId});
  final DuesProgressDto dues;
  final bool canManage;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final parts = dues.period.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final lastDay = DateTime.utc(y, m + 1, 0).day;
    final unpaid = dues.unpaid;
    final progress = dues.totalCount == 0 ? 0.0 : dues.paidCount / dues.totalCount;

    return FundCard(
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(child: CustomPaint(painter: _Ring(progress))),
                Text(
                  '${dues.paidCount}/${dues.totalCount}',
                  style: AppText.display(22).copyWith(fontStyle: FontStyle.normal),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quỹ ${Fmt.periodLabel(dues.period)} · ${_short(dues.amount)}/người',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  unpaid.isEmpty
                      ? 'Hạn $lastDay/$m · cả đội đã đóng'
                      : 'Hạn $lastDay/$m · ${unpaid.length} người chưa đóng',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
                ),
                if (unpaid.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      MiniAvatarStack(
                        names: [for (final p in unpaid.take(3)) p.name],
                        extra: unpaid.length > 3 ? unpaid.length - 3 : 0,
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showUnpaid(context),
                        child: const SizedBox(
                          height: AppSizes.tapTarget,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'Chi tiết',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lime,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 200000 → "200K"; số lẻ nghìn thì ghi đủ.
  static String _short(int v) => v % 1000 == 0 ? '${v ~/ 1000}K' : Fmt.money(v);

  void _showUnpaid(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceCard,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHƯA ĐÓNG QUỸ ${Fmt.periodLabel(dues.period)} · ${dues.unpaid.length}',
                style: AppText.display(22),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in dues.unpaid)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Avatar(name: p.name, url: p.avatarUrl, size: 36),
                        title: Text(p.name),
                      ),
                  ],
                ),
              ),
              if (canManage)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      context.push(
                        Routes.teamFundNew,
                        extra: AddFundTxArgs.dues(period: dues.period, amount: dues.amount),
                      );
                    },
                    child: const Text('Ghi nhận đóng quỹ'),
                  ),
                )
              else if (myId != null && dues.unpaid.any((p) => p.userId == myId))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      context.push(Routes.teamFundPay);
                    },
                    child: const Text('Đóng quỹ'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.teamId, required this.recent, required this.canManage});
  final String teamId;
  final List<FundTxDto> recent;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    return FundCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Expanded(child: FundLabel('Giao dịch gần đây')),
                if (recent.isNotEmpty)
                  InkWell(
                    onTap: () => context.push(Routes.teamFundsAll),
                    child: const SizedBox(
                      height: AppSizes.tapTarget,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            'Tất cả',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lime,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có khoản nào. Thủ quỹ bấm “Thêm khoản” để ghi thu, chi, phạt.',
                style: TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ),
          for (final (i, t) in recent.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            FundTxRow(teamId: teamId, tx: t, canManage: canManage),
          ],
        ],
      ),
    );
  }
}
