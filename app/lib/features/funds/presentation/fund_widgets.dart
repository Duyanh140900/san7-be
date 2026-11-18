import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../team/team_providers.dart';
import '../data/funds_repository.dart';
import 'fund_style.dart';

FundTypeValue fundType(FundType t) => switch (t) {
  FundTypeKnown(:final value) => value,
  _ => FundTypeValue.income,
};

/// Một dòng giao dịch (màn 6). Thủ quỹ/đội trưởng bấm để đánh dấu đã nộp phạt hoặc xoá.
class FundTxRow extends ConsumerWidget {
  const FundTxRow({super.key, required this.teamId, required this.tx, required this.canManage});

  final String teamId;
  final FundTxDto tx;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = fundType(tx.type);
    final member = tx.member?.name;
    final date = Fmt.dayMonth(tx.createdAt);
    final receiptUrl = tx.receiptUrl;

    final title = switch (type) {
      FundTypeValue.income => member != null ? '${tx.category} · $member' : tx.category,
      FundTypeValue.fine => 'Tiền phạt · ${member ?? ''} ${tx.category.toLowerCase()}'.trim(),
      FundTypeValue.expense =>
        tx.event != null ? '${tx.category} · ${tx.event!.title}' : tx.category,
    };
    final sub = [
      date,
      if (type == FundTypeValue.expense && member != null) '$member chi',
      if (type == FundTypeValue.fine) tx.paid ? 'từ sổ phạt' : 'chưa nộp',
      ?tx.note,
    ].join(' · ');

    final amountText = switch (type) {
      FundTypeValue.income => '+${Fmt.money(tx.amount)}',
      FundTypeValue.expense => Fmt.money(-tx.amount),
      FundTypeValue.fine => tx.paid ? '+${Fmt.money(tx.amount)}' : Fmt.money(tx.amount),
    };
    final amountColor = switch (type) {
      FundTypeValue.expense => FundStyle.redText,
      FundTypeValue.fine when !tx.paid => AppColors.textDim,
      _ => AppColors.lime,
    };

    // Ô icon 42x42, bo 14: màu theo loại khoản
    final Widget iconTile = switch (type) {
      FundTypeValue.income => _tile(AppColors.lime, AppIcons.arrowUp, AppColors.lime),
      FundTypeValue.fine => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.trophy.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Image.asset('assets/images/icon3d_yellow_card.webp', width: 32, height: 32),
      ),
      FundTypeValue.expense when tx.category == 'Tiền sân' => _tile(
        AppColors.card,
        AppIcons.pin,
        FundStyle.redText,
      ),
      FundTypeValue.expense => _tile(AppColors.home, AppIcons.cup, AppColors.homeText, alpha: 0.16),
    };

    return InkWell(
      onTap: canManage ? () => _actions(context, ref, type) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            iconTile,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
            if (receiptUrl != null)
              IconButton(
                tooltip: 'Xem biên lai',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => showReceipt(context, ref, receiptUrl),
                icon: const AppIcon(AppIcons.image, color: AppColors.lime),
              )
            else
              const SizedBox(width: 8),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: amountColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Color bg, AppIcons icon, Color fg, {double alpha = 0.14}) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: bg.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(14),
    ),
    alignment: Alignment.center,
    child: AppIcon(icon, color: fg),
  );

  Future<void> _actions(BuildContext context, WidgetRef ref, FundTypeValue type) async {
    final repo = ref.read(fundsRepositoryProvider);
    final unpaidFine = type == FundTypeValue.fine && !tx.paid;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unpaidFine)
              ListTile(
                title: const Text('Đánh dấu đã nộp phạt'),
                subtitle: Text('Cộng ${Fmt.money(tx.amount)} vào quỹ'),
                onTap: () => Navigator.pop(context, 'pay'),
              ),
            ListTile(
              title: const Text('Xoá khoản này', style: TextStyle(color: AppColors.card)),
              subtitle: const Text('Số dư quỹ được hoàn lại'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final ok = await runAction(
      context,
      () => choice == 'pay' ? repo.markFinePaid(teamId, tx.id) : repo.remove(teamId, tx.id),
      success: choice == 'pay' ? 'Đã ghi nhận nộp phạt' : 'Đã xoá khoản',
    );
    if (ok) ref.invalidate(fundSummaryProvider(teamId));
  }
}

/// Xem ảnh biên lai toàn màn hình; ảnh cần Bearer nên tải qua Dio của app.
Future<void> showReceipt(BuildContext context, WidgetRef ref, String url) {
  final future = ref.read(fundsRepositoryProvider).receiptBytes(url);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 200),
        child: FutureBuilder<Uint8List>(
          future: future,
          builder: (ctx, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Không tải được biên lai')),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            return InteractiveViewer(child: Image.memory(snap.data!));
          },
        ),
      ),
    ),
  );
}
