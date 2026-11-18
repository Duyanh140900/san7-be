import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';

/// 31 ngày tới (đủ cho giới hạn đặt trước 30 ngày), mỗi ngày là 00:00 giờ VN.
List<DateTime> nextDays({int count = 31, DateTime? now}) {
  final start = Fmt.vnDayStart(now ?? DateTime.now());
  return [for (var i = 0; i < count; i++) start.add(Duration(days: i))];
}

/// Nút kính vuông bo 14 (quay lại, thao tác phụ) trên nền tối hoặc ảnh bìa.
class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.icon, required this.label, required this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.lineStrong),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          child: Center(child: AppIcon(icon, color: AppColors.textMain)),
        ),
      ),
    ),
  );
}

/// Đầu trang kiểu bản vẽ v2: nút quay lại kính + tiêu đề Barlow Condensed + dòng phụ.
class V2Header extends StatelessWidget {
  const V2Header({super.key, required this.title, this.subtitle, this.trailing, this.onBack});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(
      children: [
        GlassButton(
          icon: AppIcons.back,
          label: 'Quay lại',
          onTap: onBack ?? () => context.canPop() ? context.pop() : context.go(Routes.pitches),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(26),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Thẻ nền #0E1F16 bo 24 (khối nội dung của các màn đặt sân).
class V2Card extends StatelessWidget {
  const V2Card({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.surfaceCard,
    this.borderColor = AppColors.line,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

/// Nhãn nhỏ viết hoa cách chữ phía trên khối ("THÊM DỊCH VỤ").
class V2Label extends StatelessWidget {
  const V2Label(this.text, {super.key, this.color = AppColors.textDim});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: color,
    ),
  );
}

/// Nhãn nhỏ tiện ích (Đèn LED, Gửi xe...).
class AmenityTags extends StatelessWidget {
  const AmenityTags(this.amenities, {super.key, this.small = false});
  final List<PitchDtoAmenitiesItem> amenities;

  /// Cỡ nhỏ (thẻ trên bản đồ): chữ 11, bo 8.
  final bool small;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: small ? 6 : 8,
    runSpacing: small ? 6 : 8,
    children: [
      for (final a in amenities)
        Container(
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(small ? 8 : AppRadius.group),
            border: small ? null : Border.all(color: AppColors.line),
          ),
          child: Text(
            Labels.amenity(a),
            style: TextStyle(
              fontSize: small ? 11 : 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
    ],
  );
}

/// Dải chọn ngày cuộn ngang: thứ nhỏ phía trên, số ngày Barlow phía dưới.
/// Mở ra là cuộn sẵn tới ngày đang chọn.
class DayStrip extends StatefulWidget {
  const DayStrip({super.key, required this.days, required this.selected, required this.onSelect});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<DayStrip> {
  static const _itemW = 56.0;
  static const _gap = 8.0;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final i = widget.days.indexOf(widget.selected);
    _scroll = ScrollController(initialScrollOffset: i <= 0 ? 0 : (i - 1) * (_itemW + _gap));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 68,
    child: ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: widget.days.length,
      separatorBuilder: (_, _) => const SizedBox(width: _gap),
      itemBuilder: (context, i) {
        final d = widget.days[i];
        final on = d == widget.selected;
        return Semantics(
          button: true,
          selected: on,
          label: Fmt.longDay(d),
          excludeSemantics: true,
          child: Material(
            color: on ? AppColors.lime : AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: InkWell(
              onTap: () => widget.onSelect(d),
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: _itemW,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: on ? null : Border.all(color: AppColors.line),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Fmt.weekday(d),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: on ? AppColors.ink : AppColors.textDim,
                      ),
                    ),
                    Text(
                      '${Fmt.vn(d).day}',
                      style: AppText.score(
                        24,
                        color: on ? AppColors.ink : AppColors.textMain,
                      ).copyWith(letterSpacing: 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Lưới khung giờ 2 cột: giờ Barlow + giá và số sân còn (hoặc "Hết sân" / "Đã qua").
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.slots,
    required this.selected,
    required this.onSelect,
    this.currentStart,
  });
  final List<PitchSlotDto> slots;
  final DateTime? selected;

  /// Khung đang đặt (khi đổi giờ): ghi "Đang đặt" thay vì "Hết sân".
  final DateTime? currentStart;
  final ValueChanged<PitchSlotDto> onSelect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final s in slots)
          _SlotButton(
            slot: s,
            selected: selected == s.startAt && s.available,
            note: s.available
                ? '${Fmt.money(s.price)} · còn ${s.free} sân'
                : s.startAt.isBefore(now)
                ? 'Đã qua'
                : s.startAt == currentStart
                ? 'Đang đặt'
                : 'Hết sân',
            onTap: s.available ? () => onSelect(s) : null,
          ),
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.selected,
    required this.note,
    required this.onTap,
  });
  final PitchSlotDto slot;
  final bool selected;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    final fg = selected ? AppColors.ink : (off ? AppColors.disabled : AppColors.textMain);
    final sub = selected ? AppColors.ink : (off ? AppColors.disabled : AppColors.textMuted);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      child: Material(
        color: selected ? AppColors.lime : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: selected ? null : Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.time(slot.startAt),
                  style: AppText.score(22, color: fg).copyWith(letterSpacing: 0),
                ),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Điểm sao trung bình ("4,8") từ danh sách đánh giá, null nếu chưa có.
double? averageStars(List<PitchReviewDto> reviews) =>
    reviews.isEmpty ? null : reviews.fold<double>(0, (a, r) => a + r.stars.toDouble()) / reviews.length;
