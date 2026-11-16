import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pitch_art.dart';
import '../../posts/posts_providers.dart';
import '../../posts/presentation/post_widgets.dart';
import '../../team/team_providers.dart';
import '../data/pitches_repository.dart';
import '../pitches_providers.dart';
import 'pitch_detail_screen.dart';
import 'reschedule_sheet.dart';

/// Màn 15 · Xác nhận đặt sân (đang giữ chỗ) và màn 16 · Vé đặt sân (đã xác nhận).
/// Bản này trả tiền tại sân; cọc online làm sau.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.teamId, required this.bookingId});
  final String teamId;
  final String bookingId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  Timer? _tick;
  bool _busy = false;
  bool _expiryRefetched = false;

  BookingKey get _key => (teamId: widget.teamId, bookingId: widget.bookingId);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final b = ref.read(bookingProvider(_key)).value;
      final until = b?.heldUntil;
      // Hết hạn giữ chỗ: tải lại một lần để lấy trạng thái thật từ server
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
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    _refreshAll(b);
  }

  /// Thoát khỏi màn xác nhận khi chưa xác nhận: nhả chỗ đang giữ ngay, khỏi chiếm quota 10 phút.
  void _releaseHold() {
    final b = ref.read(bookingProvider(_key)).value;
    final until = b?.heldUntil;
    final canManage = ref.read(managedTeamsProvider).any((t) => t.teamId == widget.teamId);
    if (b == null || b.status != BookingStatus.held || !canManage) return;
    if (until == null || !until.isAfter(DateTime.now())) return;
    // Container thay ref: lời gọi hoàn tất sau khi màn đã đóng
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(bookingsRepositoryProvider)
        .cancel(widget.teamId, b.id)
        .then((_) {
          container.invalidate(pitchDetailProvider);
          container.invalidate(pitchListProvider);
          container.invalidate(teamBookingsProvider(widget.teamId));
        })
        .catchError((_) {});
  }

  Future<void> _confirm(BookingDto b) => _run(
    b,
    () => ref.read(bookingsRepositoryProvider).confirm(widget.teamId, b.id),
    success: 'Đã đặt sân, anh em có thể điểm danh',
  );

  Future<void> _cancel(BookingDto b) async {
    final held = b.status == BookingStatus.held;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(held ? 'Huỷ giữ chỗ?' : 'Huỷ đặt sân?'),
        content: Text(
          held
              ? 'Sân sẽ được trả lại cho người khác đặt.'
              : 'Sân sẽ được trả lại, lịch đội gỡ bỏ và các thành viên được báo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: Text(held ? 'Huỷ giữ chỗ' : 'Huỷ đặt sân'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _run(
      b,
      () => ref.read(bookingsRepositoryProvider).cancel(widget.teamId, b.id),
      success: held ? 'Đã huỷ giữ chỗ' : 'Đã huỷ đặt sân',
    );
    if (held && mounted && context.canPop()) context.pop();
  }

  Future<void> _reschedule(BookingDto b) async {
    final startAt = await showRescheduleSheet(context, b);
    if (startAt == null || !mounted) return;
    await _run(
      b,
      () => ref.read(bookingsRepositoryProvider).reschedule(widget.teamId, b.id, startAt),
      success: 'Đã đổi giờ đặt sân',
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider(_key));
    final canManage = ref.watch(managedTeamsProvider).any((t) => t.teamId == widget.teamId);
    final auth = ref.watch(authControllerProvider);
    final teamName = auth is AuthSignedIn
        ? auth.me.teams.where((t) => t.teamId == widget.teamId).firstOrNull?.name
        : null;
    final b = booking.value;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _releaseHold();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: b == null
              ? Column(
                  children: [
                    const DetailHeader(backLabel: 'Sân'),
                    Expanded(
                      child: Center(
                        child: AsyncView(
                          value: booking,
                          onRetry: () => ref.invalidate(bookingProvider(_key)),
                          data: (_) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                )
              : switch (b.status) {
                  BookingStatusKnown(value: BookingStatusValue.confirmed) => _Ticket(
                    booking: b,
                    teamName: teamName,
                    canManage: canManage,
                    busy: _busy,
                    onReschedule: () => _reschedule(b),
                    onCancel: () => _cancel(b),
                  ),
                  BookingStatusKnown(value: BookingStatusValue.held) => _Hold(
                    booking: b,
                    teamName: teamName,
                    canManage: canManage,
                    busy: _busy,
                    onConfirm: () => _confirm(b),
                    onCancel: () => _cancel(b),
                  ),
                  _ => _Cancelled(booking: b),
                },
        ),
      ),
    );
  }
}

/// "09:41"
String _mmss(Duration d) {
  final s = d.inSeconds.clamp(0, 5999);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class _PitchSummary extends StatelessWidget {
  const _PitchSummary({required this.booking, this.teamName});
  final BookingDto booking;
  final String? teamName;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      children: [
        const PitchArt(size: 60, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${booking.pitch.name} · Sân số ${booking.courtNo}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                Fmt.eventTime(booking.startAt, booking.endAt),
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (teamName != null)
                Text(
                  'Đặt cho $teamName',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- màn 15

class _Hold extends StatelessWidget {
  const _Hold({
    required this.booking,
    required this.teamName,
    required this.canManage,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
  });
  final BookingDto booking;
  final String? teamName;
  final bool canManage;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final left = (booking.heldUntil ?? DateTime.now()).difference(DateTime.now());
    final expired = left.isNegative || left == Duration.zero;
    return Column(
      children: [
        const DetailHeader(backLabel: 'Sân', title: 'Xác nhận đặt sân'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              StatusBanner(
                tone: expired ? BannerTone.neutral : BannerTone.waiting,
                icon: const AppIcon(AppIcons.clock),
                child: expired
                    ? const Text('Đã hết thời gian giữ chỗ. Chọn lại khung giờ để đặt.')
                    : Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Đang giữ sân cho bạn · còn '),
                            TextSpan(
                              text: _mmss(left),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              _PitchSummary(booking: booking, teamName: teamName),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'THANH TOÁN',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row('Tiền sân', Fmt.money(booking.price)),
                    _Row('Đặt cọc bây giờ', Fmt.money(booking.deposit)),
                    _Row(
                      'Trả tại sân',
                      Fmt.money(booking.price - booking.deposit),
                      bold: true,
                      last: true,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Trả tiền mặt hoặc chuyển khoản tại quầy khi nhận sân. '
                  'Thanh toán cọc online sẽ có ở bản sau.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        BottomActionBar(
          children: [
            if (expired)
              FilledButton(
                onPressed: () => context.pushReplacement(Routes.pitch(booking.pitch.id)),
                child: const Text('Chọn lại khung giờ'),
              )
            else if (canManage) ...[
              FilledButton(
                onPressed: busy ? null : onConfirm,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác nhận đặt sân'),
              ),
              SoftButton(
                label: 'Huỷ giữ chỗ',
                color: AppColors.red,
                onPressed: busy ? null : onCancel,
              ),
            ] else
              const Text(
                'Chỉ đội trưởng hoặc phó đội xác nhận được.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.last = false});
  final String label;
  final String value;
  final bool bold;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 52),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? AppColors.text : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppColors.primary : AppColors.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- màn 16

class _Ticket extends ConsumerWidget {
  const _Ticket({
    required this.booking,
    required this.teamName,
    required this.canManage,
    required this.busy,
    required this.onReschedule,
    required this.onCancel,
  });
  final BookingDto booking;
  final String? teamName;
  final bool canManage;
  final bool busy;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTeam = ref.watch(currentTeamIdProvider);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.greenBright,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Đã đặt sân!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Đã báo các thành viên và mở điểm danh',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 18),
              _TicketCard(booking: booking),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Quick(
                    icon: AppIcons.pin,
                    label: 'Chỉ đường',
                    onTap: () => openDirections(context, booking.pitch.lat, booking.pitch.lng),
                  ),
                  _Quick(
                    icon: AppIcons.calendar,
                    label: 'Lịch đội',
                    onTap: () => booking.eventId != null && currentTeam == booking.teamId
                        ? context.push(Routes.teamEvent(booking.eventId!))
                        : context.go(Routes.teamSchedule),
                  ),
                  _Quick(
                    icon: AppIcons.qr,
                    label: 'Sao chép mã',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: booking.code));
                      if (context.mounted) showToast(context, 'Đã sao chép mã ${booking.code}', type: ToastType.success);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (canManage && booking.canChange)
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Action(label: 'Đổi giờ', onTap: busy ? null : onReschedule),
                      const Divider(height: 1, color: AppColors.divider),
                      _Action(
                        label: 'Huỷ đặt sân',
                        color: AppColors.red,
                        onTap: busy ? null : onCancel,
                      ),
                    ],
                  ),
                )
              else if (booking.postId != null)
                GestureDetector(
                  onTap: () => context.push(Routes.post(booking.postId!)),
                  child: const StatusBanner(
                    tone: BannerTone.neutral,
                    child: Text(
                      'Sân đang gắn với một kèo nên không đổi giờ hay huỷ được. Bấm để xem kèo.',
                    ),
                  ),
                ),
            ],
          ),
        ),
        BottomActionBar(
          children: [
            FilledButton(onPressed: () => context.go(Routes.pitches), child: const Text('Xong')),
          ],
        ),
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking});
  final BookingDto booking;

  @override
  Widget build(BuildContext context) {
    Widget kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const Spacer(),
          Text(v, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.pitch.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Sân số ${booking.courtNo} · ${booking.pitch.address}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                kv('Ngày', Fmt.longDay(booking.startAt)),
                kv('Giờ', '${Fmt.time(booking.startAt)} – ${Fmt.time(booking.endAt)}'),
                kv('Trả tại sân', Fmt.money(booking.price - booking.deposit)),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: _Dashed()),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Row(
              children: [
                Semantics(
                  label: 'Mã QR để nhận sân, mã ${booking.code}',
                  child: QrImageView(
                    data: booking.code,
                    size: 104,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.text),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mã đặt sân',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.code,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Đưa mã này cho quầy khi đến nhận sân',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Đường đứt nét ngăn phần vé (như bản vẽ).
class _Dashed extends StatelessWidget {
  const _Dashed();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 2,
    width: double.infinity,
    child: CustomPaint(painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 1), Offset(x + 6, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(label, style: TextStyle(fontSize: 16, color: color ?? AppColors.text)),
    ),
  );
}

class _Cancelled extends StatelessWidget {
  const _Cancelled({required this.booking});
  final BookingDto booking;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const DetailHeader(backLabel: 'Sân'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const StatusBanner(
              tone: BannerTone.neutral,
              child: Text('Lượt đặt này đã bị huỷ hoặc hết hạn giữ chỗ.'),
            ),
            const SizedBox(height: 14),
            _PitchSummary(booking: booking),
          ],
        ),
      ),
      BottomActionBar(
        children: [
          FilledButton(
            onPressed: () => context.pushReplacement(Routes.pitch(booking.pitch.id)),
            child: const Text('Đặt khung giờ khác'),
          ),
        ],
      ),
    ],
  );
}
