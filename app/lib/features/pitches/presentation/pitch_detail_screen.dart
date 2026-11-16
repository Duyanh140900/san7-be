import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pitch_art.dart';
import '../data/pitches_repository.dart';
import '../pitches_providers.dart';
import 'pitch_widgets.dart';

/// Ngày và khung giờ đã chọn ở màn bản đồ, truyền sang màn chi tiết.
class PitchDetailArgs {
  const PitchDetailArgs({this.day, this.slot});
  final DateTime? day;
  final DateTime? slot;
}

/// Mở bản đồ chỉ đường tới toạ độ (ứng dụng bản đồ của máy).
Future<void> openDirections(BuildContext context, num lat, num lng) async {
  final ok = await launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (!ok && context.mounted) showToast(context, 'Không mở được bản đồ chỉ đường', type: ToastType.error);
}

/// Màn 4 · Chi tiết sân và chọn giờ.
class PitchDetailScreen extends ConsumerStatefulWidget {
  const PitchDetailScreen({super.key, required this.pitchId, this.args});
  final String pitchId;
  final PitchDetailArgs? args;

  @override
  ConsumerState<PitchDetailScreen> createState() => _PitchDetailScreenState();
}

class _PitchDetailScreenState extends ConsumerState<PitchDetailScreen> {
  late DateTime _day = widget.args?.day ?? Fmt.vnDayStart(DateTime.now());
  DateTime? _slot;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _slot = widget.args?.slot;
  }

  PitchDayKey get _key => (id: widget.pitchId, date: Fmt.dateParam(_day));

  Future<void> _hold(PitchDto pitch) async {
    final team = ref.read(bookingTeamProvider);
    final slot = _slot;
    if (slot == null) return;
    if (team == null) {
      showToast(context, 'Chỉ đội trưởng hoặc phó đội mới đặt được sân', type: ToastType.warning);
      return;
    }
    setState(() => _holding = true);
    BookingDto? booking;
    final ok = await runAction(
      context,
      () async =>
          booking = await ref.read(bookingsRepositoryProvider).hold(team.teamId, pitch.id, slot),
    );
    if (!mounted) return;
    setState(() => _holding = false);
    // Số sân trống đã đổi dù thành công hay vừa hết chỗ
    ref.invalidate(pitchDetailProvider(_key));
    ref.invalidate(pitchListProvider);
    if (ok && booking != null) {
      setState(() => _slot = null);
      context.push(Routes.booking(team.teamId, booking!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(pitchDetailProvider(_key));
    final team = ref.watch(bookingTeamProvider);
    final pitch = detail.value;
    final slot = pitch?.slots.where((s) => s.startAt == _slot && s.available).firstOrNull;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(pitchDetailProvider(_key).future),
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Hero(onBack: () => context.pop()),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                      child: pitch == null
                          ? AsyncView(
                              value: detail,
                              onRetry: () => ref.invalidate(pitchDetailProvider(_key)),
                              data: (_) => const SizedBox.shrink(),
                            )
                          : _Info(pitch: pitch),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn ngày',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          DayStrip(
                            days: nextDays(),
                            selected: _day,
                            onSelect: (d) => setState(() {
                              _day = d;
                              _slot = null;
                            }),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Khung giờ · Sân 7',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${pitch?.slotMinutes ?? 90} phút / trận',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (pitch != null)
                            SlotGrid(
                              slots: pitch.slots,
                              selected: _slot,
                              onSelect: (s) => setState(() => _slot = s.startAt),
                            )
                          else if (detail.isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          if (pitch != null && pitch.freeSlots == 0)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Ngày này đã hết giờ trống. Thử chọn ngày khác.',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomBar(
            summary: slot == null
                ? 'Chọn khung giờ để đặt'
                : '${Fmt.weekday(slot.startAt)} ${Fmt.dayMonth(slot.startAt)} · ${Fmt.time(slot.startAt)} · ${pitch!.slotMinutes} phút',
            hint: slot != null && team != null ? 'Đặt cho ${team.name}' : null,
            price: slot == null ? '—' : Fmt.money(slot.price),
            busy: _holding,
            onPressed: slot == null || _holding ? null : () => _hold(pitch!),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 270,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const PitchArt(),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 16,
          child: Semantics(
            button: true,
            label: 'Quay lại',
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.back, size: 22),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.pitch});
  final PitchDto pitch;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        pitch.name,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      ),
      const SizedBox(height: 6),
      Text(
        '${pitch.address} · ${pitch.courtsCount} sân 7',
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      if (pitch.amenities.isNotEmpty) ...[const SizedBox(height: 12), AmenityTags(pitch.amenities)],
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => openDirections(context, pitch.lat, pitch.lng),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.group),
          ),
          child: Row(
            children: [
              const AppIcon(AppIcons.pin, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pitch.distanceM == null
                      ? 'Xem đường đi tới sân'
                      : '${Fmt.distance(pitch.distanceM!)} từ vị trí của bạn',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const Text('Chỉ đường', style: TextStyle(fontSize: 15, color: AppColors.primary)),
            ],
          ),
        ),
      ),
    ],
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.summary,
    required this.price,
    required this.busy,
    required this.onPressed,
    this.hint,
  });
  final String summary;
  final String? hint;
  final String price;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      border: const Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(price, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              if (hint != null)
                Text(
                  hint!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(130, 50),
            padding: const EdgeInsets.symmetric(horizontal: 28),
          ),
          onPressed: onPressed,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Đặt sân'),
        ),
      ],
    ),
  );
}
