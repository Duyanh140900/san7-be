import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Quả bóng trắng có ngũ giác đen (logo trong bản vẽ). [spin] quay chậm, tự tắt khi
/// người dùng bật "giảm chuyển động".
class BallMark extends StatefulWidget {
  const BallMark({super.key, this.size = 40, this.spin = false, this.period});
  final double size;
  final bool spin;

  /// Thời gian một vòng quay (mặc định 6 giây, màn tải dùng ~2,4 giây)
  final Duration? period;

  @override
  State<BallMark> createState() => _BallMarkState();
}

class _BallMarkState extends State<BallMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period ?? const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.spin && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _c,
        child: CustomPaint(size: Size.square(widget.size), painter: _BallPainter()),
      ),
    );
  }
}

class _BallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04;
    canvas.drawCircle(c, r - line.strokeWidth / 2, line);
    final pent = Path();
    final pr = r * 0.42;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final dir = Offset(math.cos(a), math.sin(a));
      final p = c + dir * pr;
      i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
      // 5 đường nan ra mép bóng
      canvas.drawLine(p, c + dir * (r * 0.9), line);
    }
    pent.close();
    canvas.drawPath(pent, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chấm cam nhấp nháy báo trực tiếp (LIVE, kèo nóng).
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 8, this.color = AppColors.hot});
  final double size;
  final Color color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.7 * (1 - _c.value)),
                spreadRadius: s * 1.2 * _c.value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
