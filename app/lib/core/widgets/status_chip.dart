import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'brand_mark.dart';

enum StatusKind {
  /// KÈO NÓNG (cam, chấm nhấp nháy)
  hot('KÈO NÓNG', AppColors.hot, AppColors.hotText, pulse: true),

  /// TÌM ĐỐI (cam)
  findOpponent('TÌM ĐỐI', AppColors.hot, AppColors.hotText),

  /// TUYỂN NGƯỜI (xanh Đội nhà)
  recruit('TUYỂN NGƯỜI', AppColors.home, AppColors.homeText),

  /// KẾT QUẢ (vàng Cúp)
  result('KẾT QUẢ', AppColors.trophy, AppColors.trophy),

  /// LIVE (cam, chấm nhấp nháy)
  live('LIVE', AppColors.hot, AppColors.hotText, pulse: true);

  const StatusKind(this.label, this.base, this.text, {this.pulse = false});
  final String label;
  final Color base;
  final Color text;
  final bool pulse;
}

/// Chip trạng thái viết hoa cách chữ (KÈO NÓNG / TÌM ĐỐI / TUYỂN NGƯỜI / KẾT QUẢ / LIVE).
/// [overlay] = true khi đặt trên ảnh bìa: nền đen mờ, viền màu.
class StatusChip extends StatelessWidget {
  const StatusChip(this.kind, {super.key, this.label, this.overlay = false});
  final StatusKind kind;

  /// Ghi đè chữ (vd "KÈO NÓNG · TÌM ĐỐI")
  final String? label;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final text = label ?? kind.label;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: overlay ? 11 : 10, vertical: overlay ? 6 : 5),
        decoration: BoxDecoration(
          color: overlay
              ? AppColors.night.withValues(alpha: 0.7)
              : kind.base.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: overlay ? Border.all(color: kind.base.withValues(alpha: 0.5)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (kind.pulse) ...[const LiveDot(), const SizedBox(width: 8)],
            Text(
              text,
              style: TextStyle(
                fontSize: overlay ? 11.5 : 11,
                fontWeight: FontWeight.w700,
                letterSpacing: overlay ? 1 : 0.8,
                color: kind.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
