import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';

/// Bảy ngày tới (từ hôm nay), mỗi ngày là 00:00 giờ VN.
List<DateTime> nextDays({int count = 7, DateTime? now}) {
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
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.days, required this.selected, required this.onSelect});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: days.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final d = days[i];
        final on = d == selected;
        return Semantics(
          button: true,
          selected: on,
          label: Fmt.longDay(d),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onSelect(d),
            child: Container(
              width: 56,
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
                      color: on ? const Color(0xFFCCCCCC) : AppColors.textSecondary,
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
    final fg = selected ? Colors.white : (off ? const Color(0xFFAEAEB2) : AppColors.text);
    final sub = selected
        ? AppColors.primarySoft
        : (off ? const Color(0xFFAEAEB2) : AppColors.textSecondary);
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
