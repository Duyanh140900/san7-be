import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../team/presentation/team_page_scaffold.dart';
import '../../team/team_providers.dart';
import 'add_fund_tx_screen.dart';
import 'fund_widgets.dart';

/// Tab Đội · Quỹ (màn 6).
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
              _BalanceCard(summary: s, month: month, canManage: canManage),
              if (s.dues != null) ...[
                const SizedBox(height: 14),
                _DuesCard(dues: s.dues!, canManage: canManage),
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.month, required this.canManage});
  final FundSummaryDto summary;
  final int month;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    Widget box(String label, String value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư hiện tại',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.money(summary.balance),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              box(
                'Thu tháng $month',
                '+${Fmt.money(summary.monthIncome)}',
                const Color(0xFF1F7A35),
              ),
              const SizedBox(width: 10),
              box('Chi tháng $month', Fmt.money(-summary.monthExpense), AppColors.text),
            ],
          ),
          if (summary.unpaidFines > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Tiền phạt chưa nộp: ${Fmt.money(summary.unpaidFines)}',
              style: const TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.tapTarget),
                    ),
                    onPressed: () => context.push(Routes.teamFundNew),
                    child: const Text('Thêm khoản', style: TextStyle(fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.background,
                      minimumSize: const Size.fromHeight(AppSizes.tapTarget),
                    ),
                    onPressed: () =>
                        showToast(context, 'Nhắc đóng quỹ qua thông báo đẩy sẽ có ở bản sau.'),
                    child: const Text('Nhắc đóng quỹ', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DuesCard extends StatelessWidget {
  const _DuesCard({required this.dues, required this.canManage});
  final DuesProgressDto dues;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final parts = dues.period.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final lastDay = DateTime.utc(y, m + 1, 0).day;
    final unpaid = dues.unpaid;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader('Quỹ ${Fmt.periodLabel(dues.period)} · ${Fmt.money(dues.amount)}/người'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${dues.paidCount} / ${dues.totalCount} đã đóng',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              Text(
                'Hạn $lastDay/$m',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: dues.totalCount == 0 ? 0 : dues.paidCount / dues.totalCount,
              minHeight: 8,
              backgroundColor: const Color(0xFFF0F0F0),
              color: AppColors.green,
            ),
          ),
          if (unpaid.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 36,
                  width: 36.0 + 26 * (unpaid.length.clamp(1, 4) - 1),
                  child: Stack(
                    children: [
                      for (final (i, p) in unpaid.take(3).indexed)
                        Positioned(
                          left: i * 26.0,
                          child: Avatar(
                            name: p.name,
                            url: p.avatarUrl,
                            size: 36,
                            border: Colors.white,
                          ),
                        ),
                      if (unpaid.length > 3)
                        Positioned(
                          left: 3 * 26.0,
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.text,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              '+${unpaid.length - 3}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'chưa đóng',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                LinkButton('Chi tiết', onTap: () => _showUnpaid(context)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showUnpaid(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chưa đóng quỹ ${Fmt.periodLabel(dues.period)} · ${dues.unpaid.length}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheet);
                    context.push(
                      Routes.teamFundNew,
                      extra: AddFundTxArgs.dues(period: dues.period, amount: dues.amount),
                    );
                  },
                  child: const Text('Ghi nhận đóng quỹ'),
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
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          CardHeader(
            'Giao dịch gần đây',
            trailing: recent.isEmpty
                ? null
                : LinkButton('Tất cả', onTap: () => context.push(Routes.teamFundsAll)),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có khoản nào. Thủ quỹ bấm “Thêm khoản” để ghi thu, chi, phạt.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          for (final (i, t) in recent.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
            FundTxRow(teamId: teamId, tx: t, canManage: canManage),
          ],
        ],
      ),
    );
  }
}
