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
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/pitch_art.dart';
import '../../team/team_providers.dart';
import '../data/pitches_repository.dart';
import '../pitches_providers.dart';
import 'pitch_detail_screen.dart';
import 'pitch_widgets.dart';
import 'reschedule_sheet.dart';

/// Màn 19 · Xác nhận đặt sân & cọc (đang giữ chỗ) và Màn 06 · Đặt thành công / Vé sân (đã xác nhận).
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.teamId, required this.bookingId});
  final String teamId;
  final String bookingId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  Timer? _tick;
  bool _expiryRefetched = false;

  // Trạng thái cho Màn 19 (dịch vụ thêm & chia tiền)
  int _water = 1;
  bool _bib = false;
  bool _split = true;
  int _method = 1; // 0: Ví, 1: QR, 2: Thẻ

  BookingKey get _key => (teamId: widget.teamId, bookingId: widget.bookingId);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final b = ref.read(bookingProvider(_key)).value;
      final until = b?.heldUntil;
      if (until != null && !until.isAfter(DateTime.now()) && !_expiryRefetched) {
        _expiryRefetched = true;
        ref.invalidate(bookingProvider(_key));
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _refreshAll(BookingDto b) {
    ref.invalidate(bookingProvider(_key));
    ref.invalidate(teamBookingsProvider(widget.teamId));
    ref.invalidate(upcomingEventsProvider(widget.teamId));
    ref.invalidate(pitchDetailProvider);
    ref.invalidate(pitchListProvider);
  }

  Future<void> _run(BookingDto b, Future<void> Function() action, {String? success}) async {
    await runAction(context, action, success: success);
    if (!mounted) return;
    _refreshAll(b);
  }

  Future<void> _cancel(BookingDto b) async {
    final held = b.status == BookingStatus.held;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(held ? 'Huỷ giữ chỗ?' : 'Huỷ đặt sân?', style: const TextStyle(color: AppColors.textMain)),
        content: Text(
          held
              ? 'Sân sẽ được trả lại cho người khác đặt.'
              : 'Sân sẽ được trả lại, lịch đội gỡ bỏ và các thành viên được báo.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không', style: TextStyle(color: AppColors.textDim)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.card),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Huỷ đặt'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _run(
      b,
      () => ref.read(bookingsRepositoryProvider).cancel(widget.teamId, b.id),
      success: held ? 'Đã nhả chỗ' : 'Đã huỷ đặt sân',
    );
  }

  Future<void> _reschedule(BookingDto b) async {
    final startAt = await showRescheduleSheet(context, b);
    if (startAt == null) return;
    await _run(
      b,
      () => ref.read(bookingsRepositoryProvider).reschedule(widget.teamId, b.id, startAt),
      success: 'Đã đổi sang khung ${Fmt.slot(startAt)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(_key));
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: AsyncView(
          value: booking,
          onRetry: () => ref.invalidate(bookingProvider(_key)),
          data: (b) {
            switch (b.status) {
              case BookingStatus.held:
                return _buildHeldScreen(b);
              case BookingStatus.confirmed:
                return _buildConfirmedScreen(b);
              case BookingStatus.cancelled:
                return _buildCancelledScreen(b);
              case BookingStatus.depositClaimed:
                return _buildHeldScreen(b);
              default:
                return _buildHeldScreen(b);
            }
          },
        ),
      ),
    );
  }

  // ==========================================
  // MÀN 19: XÁC NHẬN ĐẶT SÂN & CỌC
  // ==========================================
  Widget _buildHeldScreen(BookingDto b) {
    final team = ref.watch(bookingTeamProvider);
    final until = b.heldUntil;
    final now = DateTime.now();
    final remain = until != null && until.isAfter(now) ? until.difference(now) : Duration.zero;
    final holdText = '${remain.inMinutes.toString().padLeft(2, '0')}:${(remain.inSeconds % 60).toString().padLeft(2, '0')}';

    final extraAmount = _water * 94000 + (_bib ? 60000 : 0);
    final totalAmount = b.price + extraAmount;
    final share = _split ? (totalAmount * 0.5).round() : 0;
    final mine = totalAmount - share;
    final deposit = (mine * 0.3 / 1000).round() * 1000;
    final rest = mine - deposit;

    final cancelDeadline = Fmt.time(b.startAt.subtract(const Duration(hours: 24)));

    return Stack(
      children: [
        Positioned.fill(
          bottom: 90,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              V2Header(
                title: 'Xác nhận đặt sân',
                onBack: () => context.pop(),
              ),
              // Dải đếm ngược giữ sân
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.trophy.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.trophy.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const LiveDot(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang giữ sân cho bạn · còn $holdText',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.trophy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Thẻ tóm tắt sân
              V2Card(
                borderColor: AppColors.lime.withValues(alpha: 0.25),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const PitchArt(size: 74, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b.pitch.name} · Sân ${b.courtNo}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${Fmt.weekday(b.startAt)} ${Fmt.vn(b.startAt).day}/${Fmt.vn(b.startAt).month} · ${Fmt.time(b.startAt)} – ${Fmt.time(b.endAt)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.lime,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Đặt cho ${team?.name ?? "đội của bạn"}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Khối thêm dịch vụ
              V2Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const V2Label('THÊM DỊCH VỤ'),
                    const SizedBox(height: 12),
                    // Nước suối
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.home.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.water_drop, color: AppColors.homeText, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Nước suối', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                              Text('Thùng 24 chai · 94.000đ', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        _StepperBtn(
                          label: '−',
                          onTap: _water > 0 ? () => setState(() => _water--) : null,
                        ),
                        SizedBox(
                          width: 32,
                          child: Center(
                            child: Text(
                              '$_water',
                              style: AppText.score(20, color: AppColors.textMain),
                            ),
                          ),
                        ),
                        _StepperBtn(
                          label: '+',
                          onTap: () => setState(() => _water++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Áo bib
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.hot.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.checkroom, color: AppColors.hotText, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Thuê áo bib', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                              Text('14 áo · 60.000đ', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _bib,
                          activeThumbColor: AppColors.lime,
                          onChanged: (v) => setState(() => _bib = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.line),
                    const SizedBox(height: 12),
                    // Chia tiền theo kèo
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('MĐ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textMain)),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chia tiền với đội đối', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                              Text('FC Mỹ Đình · theo kèo 40 – 60', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _split,
                          activeThumbColor: AppColors.lime,
                          onChanged: (v) => setState(() => _split = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Bảng tính tiền & cọc
              V2Card(
                child: Column(
                  children: [
                    _PriceLine(label: 'Tiền sân', value: Fmt.money(b.price)),
                    _PriceLine(label: 'Dịch vụ', value: Fmt.money(extraAmount)),
                    if (_split)
                      _PriceLine(
                        label: 'Phần đội bạn (tạm tính 50%)',
                        value: '−${Fmt.money(share)}',
                        valueColor: AppColors.lime,
                      ),
                    const Divider(height: 16, color: AppColors.line),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const Text(
                          'Đặt cọc bây giờ (30%)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
                        ),
                        Text(
                          Fmt.money(deposit),
                          style: AppText.score(28, color: AppColors.lime),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Còn lại ${Fmt.money(rest)} trả tại sân. Huỷ miễn phí trước $cancelDeadline.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Phương thức thanh toán
              V2Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const V2Label('THANH TOÁN CỌC BẰNG'),
                    const SizedBox(height: 8),
                    _MethodItem(
                      index: 0,
                      selected: _method == 0,
                      title: 'Ví điện tử',
                      subtitle: 'Xác nhận trong app ví',
                      icon: Icons.account_balance_wallet,
                      iconColor: AppColors.hot,
                      onTap: () => setState(() => _method = 0),
                    ),
                    const SizedBox(height: 8),
                    _MethodItem(
                      index: 1,
                      selected: _method == 1,
                      title: 'Chuyển khoản QR',
                      subtitle: 'Quét mã bằng app ngân hàng',
                      icon: Icons.qr_code,
                      iconColor: AppColors.lime,
                      onTap: () => setState(() => _method = 1),
                    ),
                    const SizedBox(height: 8),
                    _MethodItem(
                      index: 2,
                      selected: _method == 2,
                      title: 'Thẻ ATM / quốc tế',
                      subtitle: 'Nhập thẻ ở bước sau',
                      icon: Icons.credit_card,
                      iconColor: AppColors.home,
                      onTap: () => setState(() => _method = 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Nút đặt cọc cố định phía dưới
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.night.withValues(alpha: 0.96),
              border: const Border(top: BorderSide(color: AppColors.line)),
            ),
            child: LimeButton(
              label: 'Thanh toán cọc ${Fmt.money(deposit)}',
              trailingIcon: AppIcons.chevronRight,
              onPressed: () => context.push(Routes.bookingQr(widget.teamId, b.id)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MÀN 06: ĐẶT SÂN THÀNH CÔNG (VÉ VÀO SÂN)
  // ==========================================
  Widget _buildConfirmedScreen(BookingDto b) {
    final deposit = b.deposit > 0 ? b.deposit : (b.price * 0.3).round();
    final rest = (b.price + b.extraAmount) - deposit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Visual VÀO!
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'VÀO!',
              style: AppText.display(24, color: AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'ĐÃ ĐẶT SÂN!',
            style: AppText.display(40),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Đã cọc ${Fmt.money(deposit)} · đã báo các thành viên và mở điểm danh',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 20),

        // Thẻ vé vào sân (Ticket card)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7F3),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.pitch.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: Color(0xFF3E5246),
                                ),
                              ),
                              Text(
                                'Sân số ${b.courtNo}',
                                style: AppText.display(30, color: const Color(0xFF06110B)),
                              ),
                              Text(
                                b.pitch.address,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF3E5246)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06110B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ĐÃ XÁC NHẬN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lime,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _TicketMeta(label: 'Ngày', value: '${Fmt.weekday(b.startAt)}, ${Fmt.vn(b.startAt).day}/${Fmt.vn(b.startAt).month}'),
                        _TicketMeta(label: 'Giờ', value: '${Fmt.time(b.startAt)}–${Fmt.time(b.endAt)}'),
                        _TicketMeta(label: 'Trả tại sân', value: Fmt.money(rest)),
                      ],
                    ),
                  ],
                ),
              ),
              // Vết răng cưa
              const _TicketNotchDivider(),
              // Mã QR & mã đặt sân
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Row(
                  children: [
                    QrImageView(
                      data: b.code,
                      size: 80,
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mã đặt sân',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3E5246)),
                          ),
                          Text(
                            b.code,
                            style: AppText.score(32, color: const Color(0xFF06110B)),
                          ),
                          const Text(
                            'Đưa mã này cho quầy khi đến nhận sân',
                            style: TextStyle(fontSize: 12, color: Color(0xFF3E5246)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 4 nút thao tác nhanh
        Row(
          children: [
            Expanded(
              child: _QuickBtn(
                icon: Icons.directions,
                label: 'Chỉ đường',
                onTap: () => openDirections(context, b.pitch.lat, b.pitch.lng),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickBtn(
                icon: Icons.calendar_month,
                label: 'Lịch đội',
                onTap: () => context.push(Routes.teamSchedule),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickBtn(
                icon: Icons.share,
                label: 'Chia sẻ',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'Sân ${b.pitch.name} · ${Fmt.slot(b.startAt)} · Mã ${b.code}'));
                  showToast(context, 'Đã sao chép thông tin vé', type: ToastType.success);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _QuickBtn(
                icon: Icons.access_time,
                label: 'Đổi giờ',
                onTap: b.canChange ? () => _reschedule(b) : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        LimeButton(
          label: 'Xong',
          onPressed: () => context.go(Routes.pitches),
        ),
        const SizedBox(height: 10),
        if (b.canChange)
          Center(
            child: TextButton(
              onPressed: () => _cancel(b),
              child: Text(
                'Huỷ đặt sân · hoàn cọc theo chính sách',
                style: TextStyle(color: AppColors.card.withValues(alpha: 0.85), fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCancelledScreen(BookingDto b) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        V2Header(title: 'Lượt đặt sân', onBack: () => context.pop()),
        const Spacer(),
        const Icon(Icons.cancel_outlined, size: 64, color: AppColors.card),
        const SizedBox(height: 14),
        const Text(
          'Lượt đặt này đã bị huỷ hoặc hết hạn',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMain),
        ),
        const SizedBox(height: 8),
        Text(
          '${b.pitch.name} · Sân ${b.courtNo}',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        const Spacer(),
        LimeButton(
          label: 'Đặt khung giờ khác',
          onPressed: () => context.pushReplacement(Routes.pitch(b.pitch.id)),
        ),
      ],
    ),
  );
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textMain,
          ),
        ),
      ],
    ),
  );
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceHigh,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: onTap == null ? AppColors.disabled : AppColors.textMain,
          ),
        ),
      ),
    ),
  );
}

class _MethodItem extends StatelessWidget {
  const _MethodItem({
    required this.index,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.surfaceHigh : Colors.transparent,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.lime : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.lime : AppColors.textDim,
              size: 20,
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TicketMeta extends StatelessWidget {
  const _TicketMeta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF3E5246))),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF06110B))),
    ],
  );
}

class _TicketNotchDivider extends StatelessWidget {
  const _TicketNotchDivider();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Divider(height: 1, color: Color(0xFFD4E0D8)),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 18,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.night,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
            ),
          ),
          Container(
            width: 18,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.night,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            ),
          ),
        ],
      ),
    ],
  );
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceCard,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: onTap == null ? AppColors.disabled : AppColors.lime),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: onTap == null ? AppColors.disabled : AppColors.textMain,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
