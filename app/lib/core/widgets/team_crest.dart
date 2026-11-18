import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../theme/tokens.dart';

/// Màu huy hiệu "#RRGGBB" → Color (mặc định xanh Đội nhà nếu sai định dạng).
Color crestColorOf(String hex) =>
    Color(int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16) ?? 0xFF2F7BFF);

/// Chữ trên huy hiệu: bỏ chữ "FC", lấy chữ đầu của tối đa 2 từ ("FC Mỹ Đình" → "MĐ").
String crestLabel(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w.toUpperCase() != 'FC');
  return words.isEmpty
      ? Fmt.initials(name)
      : words.take(2).map((w) => String.fromCharCode(w.runes.first)).join().toUpperCase();
}

/// Họa tiết trên thân khiên (bản vẽ màn 00): sọc dọc giữa, vạch ngang, hai sọc, đai giữa.
enum CrestPattern { plain, centerStripe, topBand, twoStripes, midBand }

/// Phù hiệu đội dạng khiên (viewBox 40x46 như bản vẽ): màu áo + chữ viết tắt.
/// [color] là "#RRGGBB" (màu áo đội). Chữ tự đổi đen/trắng theo độ sáng của màu áo.
/// [pattern] chỉ để trang trí; mặc định tự chọn theo tên đội cho khác nhau.
class TeamCrest extends StatelessWidget {
  const TeamCrest({
    super.key,
    required this.name,
    required this.color,
    this.width = 68,
    this.pattern,
    this.glow = false,
  });
  final String name;
  final String color;
  final double width;
  final CrestPattern? pattern;

  /// Bóng màu quanh khiên (dùng khi phù hiệu to, vd đầu thẻ kèo)
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final fill = crestColorOf(color);
    final label = crestLabel(name);
    final pat = pattern ?? CrestPattern.values[name.hashCode.abs() % CrestPattern.values.length];
    final height = width * 46 / 40;
    return Semantics(
      label: 'Phù hiệu $name',
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: glow
            ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: fill.withValues(alpha: 0.45),
                    blurRadius: width * 0.3,
                    offset: Offset(0, width * 0.12),
                  ),
                ],
              )
            : null,
        child: CustomPaint(
          painter: _CrestPainter(fill, pat),
          child: Align(
            alignment: Alignment(0, pat == CrestPattern.midBand ? -0.3 : 0.12),
            child: Text(
              label,
              maxLines: 1,
              style: AppText.display(width * 0.34, color: _onColor(fill)),
            ),
          ),
        ),
      ),
    );
  }
}

Color _onColor(Color c) => c.computeLuminance() > 0.5 ? AppColors.ink : Colors.white;

class _CrestPainter extends CustomPainter {
  _CrestPainter(this.fill, this.pattern);
  final Color fill;
  final CrestPattern pattern;

  Path _shield(Size s) {
    final k = s.width / 40;
    return Path()
      ..moveTo(20 * k, 1.5 * k)
      ..lineTo(37 * k, 6.5 * k)
      ..lineTo(37 * k, 22 * k)
      ..cubicTo(37 * k, 33 * k, 29.4 * k, 40.6 * k, 20 * k, 44.5 * k)
      ..cubicTo(10.6 * k, 40.6 * k, 3 * k, 33 * k, 3 * k, 22 * k)
      ..lineTo(3 * k, 6.5 * k)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    final shield = _shield(size);
    canvas.drawPath(shield, Paint()..color = fill);
    canvas.save();
    canvas.clipPath(shield);
    final accent = _onColor(fill);
    switch (pattern) {
      case CrestPattern.plain:
        break;
      case CrestPattern.centerStripe:
        canvas.drawRect(
          Rect.fromLTWH(18 * k, 0, 4 * k, size.height),
          Paint()..color = AppColors.lime.withValues(alpha: 0.9),
        );
      case CrestPattern.topBand:
        canvas.drawRect(
          Rect.fromLTWH(0, 12.5 * k, size.width, 3 * k),
          Paint()..color = accent.withValues(alpha: 0.35),
        );
      case CrestPattern.twoStripes:
        final p = Paint()..color = AppColors.ink.withValues(alpha: 0.85);
        canvas.drawRect(Rect.fromLTWH(12 * k, 0, 4 * k, size.height), p);
        canvas.drawRect(Rect.fromLTWH(24 * k, 0, 4 * k, size.height), p);
      case CrestPattern.midBand:
        canvas.drawRect(
          Rect.fromLTWH(0, 19.5 * k, size.width, 5 * k),
          Paint()..color = AppColors.ink.withValues(alpha: 0.4),
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CrestPainter old) => old.fill != fill || old.pattern != pattern;
}

/// Avatar tròn của đội (màu huy hiệu + chữ viết tắt), dùng trên Bảng tin, thông báo.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
    this.border,
  });
  final String name;
  final String color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final fill = crestColorOf(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border != null ? Border.all(color: border!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(crestLabel(name), style: AppText.display(size * 0.42, color: _onColor(fill))),
    );
  }
}

/// Hàng avatar đội chồng lên nhau.
class TeamAvatarStack extends StatelessWidget {
  const TeamAvatarStack({super.key, required this.teams, this.size = 32});
  final List<({String name, String color})> teams;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    width: teams.isEmpty ? 0 : size + (teams.length - 1) * (size - 10),
    child: Stack(
      children: [
        for (final (i, t) in teams.indexed)
          Positioned(
            left: i * (size - 10),
            child: TeamAvatar(
              name: t.name,
              color: t.color,
              size: size,
              border: AppColors.surfaceCard,
            ),
          ),
      ],
    ),
  );
}
