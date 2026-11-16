import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../pitches_providers.dart';
import 'pitch_widgets.dart';

/// Chọn khung giờ mới của cùng sân để đổi giờ. Trả về giờ bắt đầu mới, null nếu huỷ.
Future<DateTime?> showRescheduleSheet(BuildContext context, BookingDto booking) =>
    showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => _RescheduleSheet(booking: booking),
    );

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking});
  final BookingDto booking;

  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  late DateTime _day = Fmt.vnDayStart(widget.booking.startAt);
  DateTime? _slot;

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final detail = ref.watch(pitchDetailProvider((id: b.pitch.id, date: Fmt.dateParam(_day))));
    final days = nextDays();
    final pitch = detail.value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Đổi giờ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(
              '${b.pitch.name} · hiện tại ${Fmt.slot(b.startAt)}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            DayStrip(
              days: days,
              selected: days.contains(_day) ? _day : days.first,
              onSelect: (d) => setState(() {
                _day = d;
                _slot = null;
              }),
            ),
            const SizedBox(height: 14),
            if (pitch != null)
              SlotGrid(
                // Khung hiện tại không chọn lại được
                slots: [
                  for (final s in pitch.slots)
                    s.startAt == b.startAt
                        ? PitchSlotDto(
                            startAt: s.startAt,
                            endAt: s.endAt,
                            price: s.price,
                            free: 0,
                            total: s.total,
                            available: false,
                          )
                        : s,
                ],
                selected: _slot,
                currentStart: b.startAt,
                onSelect: (s) => setState(() => _slot = s.startAt),
              )
            else
              AsyncView(
                value: detail,
                onRetry: () => ref.invalidate(
                  pitchDetailProvider((id: b.pitch.id, date: Fmt.dateParam(_day))),
                ),
                data: (_) => const SizedBox.shrink(),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _slot == null ? null : () => Navigator.pop(context, _slot),
              child: Text(_slot == null ? 'Chọn khung giờ mới' : 'Đổi sang ${Fmt.slot(_slot!)}'),
            ),
          ],
        ),
      ),
    );
  }
}
