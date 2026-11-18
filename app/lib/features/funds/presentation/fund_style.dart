import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';

/// Kiểu riêng của nhóm màn Quỹ (bản vẽ 22, 23, 40, 08): khối vàng cúp, chữ đỏ nhạt.
abstract final class FundStyle {
  /// Chữ đậm trên nền vàng
  static const goldInk = Color(0xFF1D1400);

  /// Chữ đỏ nhạt cho khoản chi, chưa nộp
  static const redText = Color(0xFFFF8A8E);

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD966), Color(0xFFE5A800), Color(0xFFA87400)],
    stops: [0, 0.6, 1],
  );
}

/// Thẻ nền #0E1F16, viền mảnh, bo 24 (class `.card` của bản vẽ).
class FundCard extends StatelessWidget {
  const FundCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

/// Nhãn nhỏ viết hoa cách chữ ("KHOẢN CẦN ĐÓNG").
class FundLabel extends StatelessWidget {
  const FundLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
      color: AppColors.textDim,
    ),
  );
}

/// Chữ viết tắt cho avatar: "Phú Lâm" → PL.
String fundInitials(String n) {
  final p = n.trim().split(RegExp(r'\s+'));
  if (p.isEmpty || p.first.isEmpty) return '?';
  if (p.length == 1) return p.first.characters.take(2).toString().toUpperCase();
  return '${p.first.characters.first}${p.last.characters.first}'.toUpperCase();
}

/// Chồng avatar tròn nhỏ đè nhau (xanh đội nhà), "+N" ở cuối.
class MiniAvatarStack extends StatelessWidget {
  const MiniAvatarStack({super.key, required this.names, this.extra = 0, this.size = 28});
  final List<String> names;
  final int extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    final items = <(String, Color, Color)>[
      for (final n in names) (fundInitials(n), AppColors.home, AppColors.textMain),
      if (extra > 0) ('+$extra', AppColors.surfaceHigh, AppColors.textMuted),
    ];
    final step = size - 8;
    return SizedBox(
      width: items.isEmpty ? 0 : size + step * (items.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, it) in items.indexed)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: it.$2,
                  border: Border.all(color: AppColors.surfaceCard, width: 2),
                ),
                child: Text(
                  it.$1,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: it.$3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
