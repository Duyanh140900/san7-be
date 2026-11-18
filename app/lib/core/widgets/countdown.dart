import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// "mm:ss" (dưới 1 giờ) hoặc "h:mm:ss"; quá hạn → "00:00".
String formatCountdown(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// Đồng hồ đếm ngược tới [target] (giờ máy). Cập nhật mỗi giây, gọi [onFinished] một lần khi hết.
/// Có thể dùng [builder] để tự dựng giao diện; không có thì hiện chữ số Barlow Condensed.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.target,
    this.onFinished,
    this.builder,
    this.style,
    this.now,
  });

  final DateTime target;
  final VoidCallback? onFinished;
  final Widget Function(BuildContext context, Duration remaining)? builder;

  /// Kiểu chữ khi không dùng [builder]
  final TextStyle? style;

  /// Hàm lấy giờ hiện tại (để test); mặc định DateTime.now
  final DateTime Function()? now;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  late Duration _left;
  var _done = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _left = widget.target.difference(_now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant Countdown old) {
    super.didUpdateWidget(old);
    if (old.target != widget.target) {
      _done = false;
      _tick();
    }
  }

  void _tick() {
    final left = widget.target.difference(_now());
    if (!mounted) return;
    setState(() => _left = left);
    if (left <= Duration.zero && !_done) {
      _done = true;
      _timer?.cancel();
      widget.onFinished?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.builder;
    if (b != null) return b(context, _left);
    return Text(
      formatCountdown(_left),
      style: widget.style ?? AppText.score(28, color: AppColors.textMain),
    );
  }
}

/// Viên thuốc "Tự huỷ sau 12:34" đặt góc ảnh bìa kèo (màn 01), chữ số cùng bề rộng.
class CountdownPill extends StatelessWidget {
  const CountdownPill({
    super.key,
    required this.target,
    this.prefix = 'Tự huỷ sau',
    this.onFinished,
    this.now,
  });
  final DateTime target;
  final String prefix;
  final VoidCallback? onFinished;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    return Countdown(
      target: target,
      onFinished: onFinished,
      now: now,
      builder: (context, left) => Semantics(
        label: '$prefix ${formatCountdown(left)}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.night.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$prefix ${formatCountdown(left)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
