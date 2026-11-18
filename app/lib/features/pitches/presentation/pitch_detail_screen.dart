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
import '../../../core/widgets/lime_button.dart';
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
  if (!ok && context.mounted) {
    showToast(context, 'Không mở được bản đồ chỉ đường', type: ToastType.error);
  }
}

/// Màn 05 · Chi tiết sân & chọn giờ (Floodlight Night v2).
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
  int _court = 1;
  bool _holding = false;
  bool _fav = false;

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
          booking = await ref.read(bookingsRepositoryProvider).hold(
            team.teamId,
            pitch.id,
            slot,
            note: 'Sân $_court',
          ),
    );
    if (!mounted) return;
    setState(() => _holding = false);
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
    final pitch = detail.value;
    final slot = pitch?.slots.where((s) => s.startAt == _slot && s.available).firstOrNull;
    final reviewsAsync = ref.watch(pitchReviewsProvider(widget.pitchId));
    final reviews = reviewsAsync.value ?? const <PitchReviewDto>[];
    final stars = averageStars(reviews) ?? 4.8;
    final count = reviews.isNotEmpty ? reviews.length : 230;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: Stack(
        children: [
          Positioned.fill(
            bottom: 96,
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pitchDetailProvider(_key));
                ref.invalidate(pitchReviewsProvider(widget.pitchId));
              },
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Hero(
                    fav: _fav,
                    onBack: () => context.pop(),
                    onFav: () => setState(() => _fav = !_fav),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pitch != null) ...[
                          _Info(
                            pitch: pitch,
                            stars: stars,
                            reviewsCount: count,
                            onReviews: () => context.push(Routes.pitchReviews(pitch.id)),
                          ),
                          const SizedBox(height: 18),
                          if (pitch.amenities.isNotEmpty) ...[
                            AmenityTags(pitch.amenities),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'CHỌN NGÀY',
                            style: AppText.display(22),
                          ),
                          const SizedBox(height: 10),
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
                              Expanded(
                                child: Text(
                                  'KHUNG GIỜ',
                                  style: AppText.display(22),
                                ),
                              ),
                              Text(
                                '${pitch.slotMinutes} phút / trận',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDim,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SlotGrid(
                            slots: pitch.slots,
                            selected: _slot,
                            onSelect: (s) => setState(() => _slot = s.startAt),
                          ),
                          if (pitch.freeSlots == 0)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Ngày này đã hết giờ trống. Thử chọn ngày khác.',
                                style: TextStyle(fontSize: 13, color: AppColors.textDim),
                              ),
                            ),
                          const SizedBox(height: 22),
                          Text(
                            'CHỌN SÂN SỐ',
                            style: AppText.display(22),
                          ),
                          const SizedBox(height: 10),
                          _CourtGrid(
                            count: pitch.courtsCount,
                            selected: _court,
                            onSelect: (c) => setState(() => _court = c),
                          ),
                        ] else if (detail.isLoading) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime)),
                          ),
                        ] else if (detail.hasError) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  const Text('Lỗi tải thông tin sân', style: TextStyle(color: AppColors.card)),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => ref.invalidate(pitchDetailProvider(_key)),
                                    child: const Text('Thử lại', style: TextStyle(color: AppColors.lime)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              summary: slot == null
                  ? 'Chọn khung giờ để đặt'
                  : '${Fmt.weekday(slot.startAt)} ${Fmt.vn(slot.startAt).day}/${Fmt.vn(slot.startAt).month} · ${Fmt.time(slot.startAt)} · Sân $_court',
              price: slot == null ? '—' : Fmt.money(slot.price),
              busy: _holding,
              onPressed: slot == null || _holding || pitch == null ? null : () => _hold(pitch),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.fav, required this.onBack, required this.onFav});
  final bool fav;
  final VoidCallback onBack;
  final VoidCallback onFav;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const PitchArt(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.night.withValues(alpha: 0.5),
                  Colors.transparent,
                  AppColors.night.withValues(alpha: 0.3),
                  AppColors.night,
                ],
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlassButton(
                  icon: AppIcons.back,
                  label: 'Quay lại',
                  onTap: onBack,
                ),
                GlassButton(
                  icon: fav ? AppIcons.heart : AppIcons.more,
                  label: 'Yêu thích',
                  onTap: onFav,
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.night.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.line),
              ),
              child: const Text(
                '1 / 8 ảnh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.pitch,
    required this.stars,
    required this.reviewsCount,
    required this.onReviews,
  });
  final PitchDto pitch;
  final double stars;
  final int reviewsCount;
  final VoidCallback onReviews;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        pitch.name.toUpperCase(),
        style: AppText.display(34),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.trophy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '★ ${stars.toStringAsFixed(1).replaceAll('.', ',')}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReviews,
            child: Text(
              '$reviewsCount đánh giá',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.lime,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '· ${pitch.district}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => openDirections(context, pitch.lat, pitch.lng),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            const AppIcon(AppIcons.pin, size: 16, color: AppColors.lime),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  if (pitch.distanceM != null)
                    '${Fmt.distance(pitch.distanceM!)} · khoảng 6 phút đi xe máy',
                  pitch.address,
                ].join(' · '),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Chỉ đường',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Lưới chọn sân số (2 cột).
class _CourtGrid extends StatelessWidget {
  const _CourtGrid({
    required this.count,
    required this.selected,
    required this.onSelect,
  });
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final n = count <= 0 ? 4 : count;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 1; i <= n; i++)
            Material(
              color: i == selected ? AppColors.lime : AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: i == selected ? null : Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'Sân $i',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: i == selected ? AppColors.ink : AppColors.textMain,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.summary,
    required this.price,
    required this.busy,
    required this.onPressed,
  });
  final String summary;
  final String price;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.paddingOf(context).bottom),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard.withValues(alpha: 0.96),
      border: const Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                price,
                style: AppText.score(28, color: AppColors.lime),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        LimeButton(
          label: 'Đặt sân',
          trailingIcon: AppIcons.chevronRight,
          loading: busy,
          onPressed: onPressed,
        ),
      ],
    ),
  );
}
