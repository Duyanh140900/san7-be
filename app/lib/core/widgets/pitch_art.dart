import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Hình sân cỏ vẽ tay (sọc cỏ + vạch sân) thay cho ảnh sân thật, như bản vẽ.
class PitchArt extends StatelessWidget {
  const PitchArt({super.key, this.size, this.radius = 0, this.child});

  /// Vuông cạnh [size]; null = lấp đầy chỗ được cấp.
  final double? size;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(painter: _PitchPainter(), child: child ?? const SizedBox.expand()),
    );
    return size == null ? art : SizedBox(width: size, height: size, child: art);
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = AppColors.pitch);
    // Sọc cỏ
    final stripe = Paint()..color = const Color(0xFF34994C);
    final w = s.width / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * w, 0, w, s.height), stripe);
    }
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s.shortestSide / 90).clamp(1.0, 2.5);
    final r = Rect.fromLTWH(s.width * .06, s.height * .14, s.width * .88, s.height * .72);
    canvas.drawRect(r, line);
    canvas.drawLine(Offset(s.width / 2, r.top), Offset(s.width / 2, r.bottom), line);
    canvas.drawCircle(Offset(s.width / 2, s.height / 2), r.height * .16, line);
    final boxH = r.height * .42;
    final boxW = r.width * .12;
    canvas.drawRect(Rect.fromLTWH(r.left, s.height / 2 - boxH / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(r.right - boxW, s.height / 2 - boxH / 2, boxW, boxH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
