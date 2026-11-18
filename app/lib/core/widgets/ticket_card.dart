import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Chỉ số nhỏ ở nửa dưới vé ("Trình độ" / "TB").
typedef TicketStat = ({String label, String value});

/// Thẻ "VÉ VÀO TRẬN" (màn 03): nền lime, giờ đá to, đường răng cưa có hai khuyết tròn,
/// hàng 3 chỉ số bên dưới. Chữ luôn tối (#06110B) trên nền lime.
class TicketCard extends StatelessWidget {
  const TicketCard({
    super.key,
    required this.time,
    required this.dateLine,
    required this.stats,
    this.caption = 'VÉ VÀO TRẬN',
    this.trailing,
    this.notchColor = AppColors.night,
  });

  /// Giờ đá cỡ lớn, vd "19:00"
  final String time;

  /// Dòng dưới giờ, vd "Thứ Bảy · 22/11 · 90 phút"
  final String dateLine;
  final List<TicketStat> stats;
  final String caption;

  /// Hình góc phải (vd icon áo đấu)
  final Widget? trailing;

  /// Màu nền màn hình, để hai khuyết tròn trông như bị cắt
  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$caption $time, $dateLine',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: ColoredBox(
          color: AppColors.lime,
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.ink),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(time, style: AppText.display(54, color: AppColors.ink)),
                            const SizedBox(height: 4),
                            Text(
                              dateLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
                _Perforation(notchColor: notchColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in stats)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.display(
                                  22,
                                  color: AppColors.ink,
                                ).copyWith(fontStyle: FontStyle.normal),
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
        ),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation({required this.notchColor});
  final Color notchColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: -11, top: 0, child: _Notch(notchColor)),
          Positioned(right: -11, top: 0, child: _Notch(notchColor)),
          Positioned.fill(
            left: 18,
            right: 18,
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = (c.maxWidth / 10).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < n; i++)
                        Container(
                          width: 5,
                          height: 2,
                          color: AppColors.ink.withValues(alpha: 0.35),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
