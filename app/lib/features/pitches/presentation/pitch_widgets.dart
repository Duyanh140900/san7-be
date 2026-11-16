import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';

/// 31 ngày tới (đủ cho giới hạn đặt trước 30 ngày), mỗi ngày là 00:00 giờ VN.
List<DateTime> nextDays({int count = 31, DateTime? now}) {
  final start = Fmt.vnDayStart(now ?? DateTime.now());
  return [for (var i = 0; i < count; i++) start.add(Duration(days: i))];
}

/// Nhãn nhỏ tiện ích (Đèn LED, Gửi xe...).
class AmenityTags extends StatelessWidget {
  const AmenityTags(this.amenities, {super.key});
  final List<PitchDtoAmenitiesItem> amenities;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final a in amenities)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            Labels.amenity(a),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
    ],
  );
}

/// Dải chọn ngày cuộn ngang: thứ nhỏ phía trên, số ngày đậm phía dưới.
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
    height: 64,
    child: ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
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
          child: GestureDetector(
            onTap: () => widget.onSelect(d),
            child: Container(
              width: _itemW,
              decoration: BoxDecoration(
                color: on ? AppColors.text : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Fmt.weekday(d),
                    style: TextStyle(
                      fontSize: 12,
                      color: on ? AppColors.onDarkMuted : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${Fmt.vn(d).day}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Lưới khung giờ 3 cột: giờ bắt đầu + giá (hoặc "Hết sân" / "Đã qua").
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
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.75,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final s in slots)
          _SlotButton(
            slot: s,
            selected: selected == s.startAt && s.available,
            note: s.available
                ? Fmt.money(s.price)
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
    final fg = selected ? Colors.white : (off ? AppColors.disabled : AppColors.text);
    final sub = selected
        ? AppColors.primarySoft
        : (off ? AppColors.disabled : AppColors.textSecondary);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !off,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : (off ? AppColors.background : AppColors.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : (off ? AppColors.background : AppColors.pillBorder),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Fmt.time(slot.startAt),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg),
              ),
              Text(note, style: TextStyle(fontSize: 12, color: sub)),
            ],
          ),
        ),
      ),
    );
  }
}
