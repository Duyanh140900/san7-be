import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../data/pitches_repository.dart';
import '../pitches_providers.dart';
import 'pitch_widgets.dart';

/// Chuỗi VietQR (EMVCo, NAPAS 247) tự sinh trên máy.
String buildVietQrPayload({
  required String bin,
  required String account,
  int? amount,
  String? memo,
}) {
  String f(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

  final bank = f('00', bin) + f('01', account);
  final merchant = f('00', 'A000000727') + f('01', bank) + f('02', 'QRIBFTTA');
  final body = StringBuffer()
    ..write(f('00', '01'))
    ..write(f('01', amount != null && amount > 0 ? '12' : '11'))
    ..write(f('38', merchant))
    ..write(f('53', '704'));
  if (amount != null && amount > 0) body.write(f('54', '$amount'));
  body.write(f('58', 'VN'));
  if (memo != null && memo.isNotEmpty) body.write(f('62', f('08', memo)));
  body.write('6304');
  return '$body${_crc16(body.toString())}';
}

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), 4 ký tự hex HOA.
String _crc16(String s) {
  var crc = 0xFFFF;
  for (final b in s.codeUnits) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Màn 36 · Chuyển khoản QR cọc sân (Floodlight Night v2).
class BookingQrScreen extends ConsumerStatefulWidget {
  const BookingQrScreen({super.key, required this.teamId, required this.bookingId});
  final String teamId;
  final String bookingId;

  @override
  ConsumerState<BookingQrScreen> createState() => _BookingQrScreenState();
}

class _BookingQrScreenState extends ConsumerState<BookingQrScreen> {
  Timer? _timer;
  bool _checking = false;
  bool _failed = false;
  bool _success = false;
  int _copiedIndex = 0; // 1: stk, 2: memo

  BookingKey get _key => (teamId: widget.teamId, bookingId: widget.bookingId);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment(BookingDto b) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _failed = false;
    });

    try {
      final res = await ref.read(bookingsRepositoryProvider).claimDeposit(widget.teamId, b.id);
      if (!mounted) return;
      setState(() => _checking = false);
      if (res.status == BookingStatus.confirmed) {
        setState(() => _success = true);
        ref.invalidate(bookingProvider(_key));
        ref.invalidate(teamBookingsProvider(widget.teamId));
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _failed = true;
      });
    }
  }

  void _copy(String text, int index, String label) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copiedIndex = index);
    showToast(context, 'Đã chép $label', type: ToastType.success);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedIndex == index) {
        setState(() => _copiedIndex = 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingProvider(_key));
    final booking = bookingAsync.value;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            V2Header(
              title: 'Chuyển khoản cọc',
              subtitle: 'Bước 2 / 2',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: booking == null
                  ? (bookingAsync.isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                      : Center(
                          child: TextButton(
                            onPressed: () => ref.invalidate(bookingProvider(_key)),
                            child: const Text('Thử lại', style: TextStyle(color: AppColors.lime)),
                          ),
                        ))
                  : _buildContent(booking),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BookingDto b) {
    final deposit = b.deposit > 0 ? b.deposit : (b.price * 0.3).round();
    final bankBin = b.pitch.bankBin ?? '970436';
    final accountNo = b.pitch.accountNo ?? '0123456789';
    final accountName = b.pitch.accountName ?? b.pitch.name.toUpperCase();
    final transferCode = b.transferCode ?? b.code;

    final qrPayload = buildVietQrPayload(
      bin: bankBin,
      account: accountNo,
      amount: deposit,
      memo: transferCode,
    );

    final until = b.heldUntil;
    final now = DateTime.now();
    final remain = until != null && until.isAfter(now) ? until.difference(now) : Duration.zero;
    final holdText = '${remain.inMinutes.toString().padLeft(2, '0')}:${(remain.inSeconds % 60).toString().padLeft(2, '0')}';

    final isConfirmed = b.status == BookingStatus.confirmed || _success;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Tiền cọc & trạng thái
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              Fmt.money(deposit),
              style: AppText.score(34, color: AppColors.lime),
            ),
            Row(
              children: [
                if (!isConfirmed) ...[
                  const LiveDot(),
                  const SizedBox(width: 6),
                ],
                Text(
                  isConfirmed
                      ? 'Đã nhận cọc — sân đã giữ'
                      : (_checking
                          ? 'Đang kiểm tra giao dịch…'
                          : (_failed ? 'Chưa nhận được tiền' : 'Đang chờ chuyển khoản')),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isConfirmed
                        ? AppColors.lime
                        : (_failed ? AppColors.card : AppColors.trophy),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Khối mã QR hoặc tick xanh khi thành công
        if (!isConfirmed) ...[
          Center(
            child: Container(
              width: 240,
              height: 240,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F7F3),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.lime, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrPayload,
                size: 212,
                padding: EdgeInsets.zero,
                backgroundColor: const Color(0xFFF2F7F3),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF06110B),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF06110B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Mở app ngân hàng · Quét QR. Số tiền và nội dung đã điền sẵn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
        ] else ...[
          Center(
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.lime.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime,
                ),
                child: const Center(
                  child: Icon(Icons.check, size: 54, color: AppColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Sân đã được giữ thành công cho đội của bạn!',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.lime),
            ),
          ),
        ],
        const SizedBox(height: 18),

        // Cảnh báo nếu kiểm tra chưa nhận được tiền
        if (_failed && !isConfirmed) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.card.withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.card, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Chưa nhận được tiền. Kiểm tra lại nội dung chuyển khoản ',
                      style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFFFFC2C4)),
                      children: [
                        TextSpan(
                          text: transferCode,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textMain),
                        ),
                        const TextSpan(
                          text: ' rồi bấm thử lại; giao dịch đôi khi trễ 1–2 phút.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Thông tin chuyển khoản
        V2Card(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              _InfoRow(
                label: 'Chủ tài khoản',
                value: accountName,
              ),
              const Divider(height: 1, color: AppColors.line),
              _InfoRow(
                label: 'Số tài khoản',
                value: accountNo,
                action: _copiedIndex == 1 ? 'Đã chép' : 'Sao chép',
                onAction: () => _copy(accountNo, 1, 'số tài khoản'),
              ),
              const Divider(height: 1, color: AppColors.line),
              _InfoRow(
                label: 'Nội dung',
                value: transferCode,
                valueColor: AppColors.lime,
                action: _copiedIndex == 2 ? 'Đã chép' : 'Sao chép',
                onAction: () => _copy(transferCode, 2, 'nội dung'),
              ),
              const Divider(height: 1, color: AppColors.line),
              _InfoRow(
                label: 'Giữ sân còn',
                value: holdText,
                valueColor: AppColors.trophy,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Nút hành động chính
        if (!isConfirmed) ...[
          LimeButton(
            label: _checking
                ? 'Đang kiểm tra…'
                : (_failed ? 'Thử kiểm tra lại' : 'Tôi đã chuyển khoản'),
            loading: _checking,
            onPressed: () => _checkPayment(b),
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Đổi phương thức',
            onPressed: () => context.pop(),
          ),
        ] else ...[
          LimeButton(
            label: 'Xem vé vào sân',
            trailingIcon: AppIcons.chevronRight,
            onPressed: () => context.go(Routes.booking(widget.teamId, b.id)),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.action,
    this.onAction,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textMain,
              letterSpacing: valueColor == AppColors.lime ? 1 : 0.5,
            ),
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: action == 'Đã chép' ? AppColors.lime : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.line),
              ),
              child: Text(
                action!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: action == 'Đã chép' ? AppColors.ink : AppColors.textMain,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
