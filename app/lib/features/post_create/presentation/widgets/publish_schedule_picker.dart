import 'package:material_ui/material_ui.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/form_widgets.dart';

/// Màn 2 · Thời điểm đăng: "Đăng ngay" hoặc "Hẹn lịch" (ngày, giờ, lặp lại hàng tuần).
class PublishSchedulePicker extends StatelessWidget {
  const PublishSchedulePicker({
    super.key,
    required this.scheduled,
    required this.publishUtc,
    required this.repeatWeekly,
    required this.onScheduledChanged,
    required this.onPickDate,
    required this.onPickTime,
    required this.onRepeatChanged,
  });

  final bool scheduled;
  final DateTime publishUtc;
  final bool repeatWeekly;
  final ValueChanged<bool> onScheduledChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final ValueChanged<bool> onRepeatChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const FormCaption('Thời điểm đăng'),
      Segmented(
        labels: const ['Đăng ngay', 'Hẹn lịch'],
        index: scheduled ? 1 : 0,
        onChanged: (i) => onScheduledChanged(i == 1),
      ),
      if (scheduled) ...[
        const SizedBox(height: 10),
        FormGroup(
          children: [
            _Row(
              label: 'Ngày đăng',
              value: '${Fmt.weekday(publishUtc)}, ${Fmt.dayMonth(publishUtc)}',
              onTap: onPickDate,
            ),
            _Row(label: 'Giờ đăng', value: Fmt.time(publishUtc), onTap: onPickTime),
            Container(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Lặp lại hàng tuần', style: TextStyle(fontSize: 16)),
                  ),
                  Switch(value: repeatWeekly, onChanged: onRepeatChanged),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text(
            'Kèo sẽ tự lên Bảng tin đúng giờ đã hẹn. Lặp lại hàng tuần sẽ dời giờ đá thêm 7 ngày mỗi lần.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
          const AppIcon(AppIcons.chevronRight, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}
