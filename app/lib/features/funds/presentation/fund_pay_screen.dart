import '../data/funds_repository.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/api/api_error.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../matches/matches_providers.dart';
import '../../team/team_providers.dart';
import 'fund_style.dart';
import 'viet_qr_payload.dart';

/// Tài khoản nhận tiền của thủ quỹ.
/// TODO(api): chưa có endpoint tài khoản thủ quỹ và "tôi đã chuyển" (đóng quỹ chờ duyệt) trong
/// docs/openapi.json. Tạm dùng số liệu giả; nối API khi Backend có (GET tài khoản thủ quỹ,
/// POST yêu cầu đóng quỹ → trạng thái pending).
class _TreasurerBank {
  const _TreasurerBank();
  final String bin = '970436';
  final String bankName = 'Vietcombank';
  final String account = '9876543210';
  String get accountSpaced => '9876 5432 10';
}

/// Màn 40 · Thành viên đóng quỹ: chọn khoản, quét VietQR, báo "Tôi đã chuyển".
class FundPayScreen extends ConsumerStatefulWidget {
  const FundPayScreen({super.key});

  @override
  ConsumerState<FundPayScreen> createState() => _FundPayScreenState();
}

class _FundPayScreenState extends ConsumerState<FundPayScreen> {
  static const _bank = _TreasurerBank();
  bool _payDues = true;
  final Set<String> _skipFines = {};
  bool _sent = false; // TODO(api): thay bằng trạng thái yêu cầu từ server
  DateTime? _sentAt;
  bool _copied = false;
  bool _sending = false;

  String _memo(String teamName, String period, String myName) {
    final words = stripVietnamese(teamName)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w != 'FC' && w != 'CLB')
        .toList();
    final prefix = words.map((w) => w[0]).join();
    final month = int.parse(period.split('-')[1]);
    final last = stripVietnamese(myName).split(RegExp(r'\s+')).last;
    return '${prefix}7 QUY T$month $last';
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _send(String teamId, int total, String memo) async {
    setState(() => _sending = true);
    try {
      await ref.read(fundsRepositoryProvider).claimTransfer(
        teamId,
        amount: total,
        transferCode: memo,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentAt = DateTime.now();
      });
      AppToast.success('Đã gửi thông báo cho thủ quỹ xác nhận');
    } catch (e) {
      if (mounted) AppToast.error(ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const Scaffold();
    final auth = ref.watch(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;
    final myName = auth is AuthSignedIn ? auth.me.name : '';
    final team = ref.watch(teamDetailProvider(teamId)).value;
    final summary = ref.watch(fundSummaryProvider(teamId));
    final members = ref.watch(membersProvider(teamId)).value?.active ?? const <MemberDto>[];
    final treasurer = members.where((m) => m.role.isTreasurer).firstOrNull;

    final dues = summary.value?.dues;
    final period = dues?.period ?? Fmt.currentPeriod();
    final iOwe = dues != null && myId != null && dues.unpaid.any((p) => p.userId == myId);
    final fines = ref.watch(finesProvider((teamId: teamId, period: period))).value;
    final myFines = [
      for (final f in fines?.items ?? const <FundTxDto>[])
        if (!f.paid && f.member?.userId == myId) f,
    ];

    final duesAmount = iOwe ? dues.amount : 0;
    final total =
        (_payDues ? duesAmount : 0) +
        myFines.where((f) => !_skipFines.contains(f.id)).fold<int>(0, (a, f) => a + f.amount);
    final memo = _memo(team?.name ?? '', period, myName);
    final nothingToPay = !iOwe && myFines.isEmpty;
    final lastDay = DateTime.utc(
      int.parse(period.split('-')[0]),
      int.parse(period.split('-')[1]) + 1,
      0,
    ).day;
    final monthNum = int.parse(period.split('-')[1]);
    final treasurerName = treasurer?.name ?? 'Thủ quỹ';
    final tBankBin = team?.treasurerBankBin ?? team?.additionalProperties['treasurerBankBin'] as String?;
    final tAccountNo = team?.treasurerAccountNo ?? team?.additionalProperties['treasurerAccountNo'] as String?;
    final tAccountName = team?.treasurerAccountName ?? team?.additionalProperties['treasurerAccountName'] as String?;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _Header(team: team?.name, treasurer: treasurer?.name),
                Expanded(
                  child: AsyncView<FundSummaryDto>(
                    value: summary,
                    onRetry: () => ref.invalidate(fundSummaryProvider(teamId)),
                    data: (s) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                      children: [
                        FundCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FundLabel('Khoản cần đóng'),
                              const SizedBox(height: 8),
                              if (nothingToPay)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Bạn không có khoản nào cần đóng. Quỹ và tiền phạt của bạn đã xong.',
                                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                                  ),
                                ),
                              if (iOwe)
                                _Line(
                                  label: 'Quỹ tháng $monthNum',
                                  amount: Fmt.money(duesAmount),
                                  on: _payDues,
                                  onTap: _sent ? null : () => setState(() => _payDues = !_payDues),
                                ),
                              for (final f in myFines)
                                _Line(
                                  label: 'Phạt ${f.category.toLowerCase()} ${Fmt.dayMonth(f.createdAt)}',
                                  amount: Fmt.money(f.amount),
                                  on: !_skipFines.contains(f.id),
                                  onTap: _sent
                                      ? null
                                      : () => setState(
                                          () => _skipFines.contains(f.id)
                                              ? _skipFines.remove(f.id)
                                              : _skipFines.add(f.id),
                                        ),
                                ),
                              if (!nothingToPay) ...[
                                const SizedBox(height: 8),
                                const _DashedLine(),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Tổng chuyển',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(
                                      Fmt.money(total),
                                      style: AppText.display(28, color: AppColors.lime).copyWith(
                                        fontStyle: FontStyle.normal,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                                if (iOwe)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Hạn $lastDay/$monthNum · ${_daysLeft(period)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        if (!_sent && !nothingToPay && total > 0) ...[
                          const SizedBox(height: 14),
                          _QrCard(
                            payload: buildVietQrPayload(
                              bin: tBankBin ?? _bank.bin,
                              account: tAccountNo ?? _bank.account,
                              amount: total,
                              memo: memo,
                            ),
                            name: stripVietnamese(tAccountName ?? treasurerName),
                            account: tAccountNo ?? _bank.accountSpaced,
                            bank: _bank.bankName,
                            memo: memo,
                            copied: _copied,
                            onCopy: () => _copy(memo),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _Steps(
                          sent: _sent,
                          sentAt: _sentAt,
                          treasurer: treasurer?.name,
                          total: total,
                        ),
                        if (dues != null) ...[
                          const SizedBox(height: 14),
                          FundCard(
                            child: Row(
                              children: [
                                MiniAvatarStack(
                                  names: const ['Văn Nam', 'Quang Tuấn'],
                                  extra: (dues.paidCount - 2).clamp(0, 99),
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${dues.paidCount} / ${dues.totalCount} người đã đóng tháng này',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0006110B), AppColors.night],
                    stops: [0, 0.3],
                  ),
                ),
                child: _sent
                    ? LimeButton(label: 'Xem quỹ đội', onPressed: () => context.pop())
                    : LimeButton(
                        label: 'Tôi đã chuyển ${Fmt.money(total)}',
                        loading: _sending,
                        onPressed: total > 0 && !_sending ? () => _send(teamId, total, memo) : null,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _daysLeft(String period) {
    final p = period.split('-');
    final end = DateTime.utc(int.parse(p[0]), int.parse(p[1]) + 1, 0);
    final today = Fmt.vnDayStart(DateTime.now());
    final d = end.difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return d < 0 ? 'đã quá hạn' : (d == 0 ? 'hết hạn hôm nay' : 'còn $d ngày');
  }
}

extension on TeamRole {
  bool get isTreasurer => switch (this) {
    TeamRoleKnown(:final value) => value == TeamRoleValue.treasurer,
    _ => false,
  };
}

class _Header extends StatelessWidget {
  const _Header({this.team, this.treasurer});
  final String? team;
  final String? treasurer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(
      children: [
        Semantics(
          button: true,
          label: 'Quay lại',
          child: InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lineStrong),
              ),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.back, color: AppColors.textMain),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ĐÓNG QUỸ ĐỘI', style: AppText.display(26)),
              Text(
                [?team, if (treasurer != null) 'thủ quỹ $treasurer'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Một khoản có ô tick vàng, bấm để chọn/bỏ.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.amount, required this.on, required this.onTap});
  final String label;
  final String amount;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: '$label $amount',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: on ? AppColors.trophy : null,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: on ? AppColors.trophy : AppColors.disabled, width: 2),
              ),
              alignment: Alignment.center,
              child: on ? const AppIcon(AppIcons.checkCircle, size: 0, color: AppColors.ink) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final n = (c.maxWidth / 12).floor();
      return Row(
        children: [
          for (var i = 0; i < n; i++)
            Container(width: 6, height: 1, margin: const EdgeInsets.only(right: 6), color: AppColors.lineButton),
        ],
      );
    },
  );
}

/// Khối vàng: mã VietQR + thông tin chuyển cho thủ quỹ.
class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.payload,
    required this.name,
    required this.account,
    required this.bank,
    required this.memo,
    required this.copied,
    required this.onCopy,
  });
  final String payload;
  final String name;
  final String account;
  final String bank;
  final String memo;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: FundStyle.goldGradient,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Row(
      children: [
        Container(
          width: 118,
          height: 118,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.textMain,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Semantics(
            label: 'Mã QR chuyển khoản cho thủ quỹ',
            child: QrImageView(
              data: payload,
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.textMain,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.night),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.night,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CHUYỂN CHO THỦ QUỸ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: FundStyle.goldInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: FundStyle.goldInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$bank · STK $account',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: FundStyle.goldInk,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: FundStyle.goldInk.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      memo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: FundStyle.goldInk,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: copied ? FundStyle.goldInk : null,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: FundStyle.goldInk.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        copied ? 'Đã chép' : 'Chép',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: copied ? AppColors.trophy : FundStyle.goldInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 3 bước: bạn chuyển → thủ quỹ xác nhận → cộng vào quỹ.
class _Steps extends StatelessWidget {
  const _Steps({
    required this.sent,
    required this.sentAt,
    required this.treasurer,
    required this.total,
  });
  final bool sent;
  final DateTime? sentAt;
  final String? treasurer;
  final int total;

  @override
  Widget build(BuildContext context) {
    final who = treasurer ?? 'Thủ quỹ';
    // (tiêu đề, phụ đề, xong, đang chờ)
    final steps = <(String, String, bool, bool)>[
      (
        'Bạn chuyển khoản',
        sent && sentAt != null ? 'Đã báo lúc ${Fmt.time(sentAt!)}' : 'Quét QR hoặc chép số tài khoản',
        sent,
        false,
      ),
      (
        'Thủ quỹ xác nhận',
        sent ? '$who đang kiểm tra…' : 'Sau khi bạn báo đã chuyển',
        false,
        sent,
      ),
      ('Cộng vào quỹ đội', 'Tự động sau khi xác nhận', false, false),
    ];
    return FundCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FundLabel('Trạng thái'),
          const SizedBox(height: 12),
          for (final (i, s) in steps.indexed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.$3 ? AppColors.lime : (s.$4 ? AppColors.trophy : null),
                        border: Border.all(
                          color: s.$3
                              ? AppColors.lime
                              : (s.$4 ? AppColors.trophy : AppColors.disabled),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: s.$3
                          ? const AppIcon(AppIcons.checkCircle, size: 0, color: AppColors.ink)
                          : null,
                    ),
                    if (i < steps.length - 1)
                      Container(
                        width: 2,
                        height: 22,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: s.$3 ? AppColors.lime : AppColors.disabled,
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: s.$3 || s.$4 ? AppColors.textMain : AppColors.textDim,
                          ),
                        ),
                        Text(
                          s.$2,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
