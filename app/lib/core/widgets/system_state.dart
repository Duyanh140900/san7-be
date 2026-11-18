import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'brand_mark.dart';
import 'lime_button.dart';

/// Màn 34 · Trạng thái hệ thống: mất mạng, lỗi 500, rỗng, đang tải.
/// Các widget dưới đây không tự chiếm cả màn hình; đặt trong `Center`, `Expanded`
/// hoặc `SliverFillRemaining` tuỳ chỗ dùng. [compact] thu nhỏ hình để nhét trong danh sách.

/// Dải cam "Đang ngoại tuyến · dữ liệu có thể đã cũ" dán trên cùng màn hình khi mất mạng
/// nhưng vẫn còn dữ liệu đã tải.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.text = 'Đang ngoại tuyến · dữ liệu có thể đã cũ'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 10),
        color: AppColors.hot,
        child: Row(
          children: [
            const AppIcon(AppIcons.wifiOff, color: AppColors.ink, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung chung: hình + tiêu đề Barlow + mô tả + hàng nút. Căn giữa, rộng tối đa 340.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.art,
    required this.title,
    required this.message,
    this.extra,
    this.actions = const [],
    this.compact = false,
  });

  final Widget art;
  final String title;
  final String message;
  final Widget? extra;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: compact ? 20 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              art,
              SizedBox(height: compact ? 12 : 16),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.display(compact ? 28 : 34),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, height: 1.55, color: AppColors.textMuted),
              ),
              if (extra != null) ...[const SizedBox(height: 16), extra!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Mất điện sân rồi!": mất kết nối mạng. Nút "Thử lại" (đổi thành "Đang thử lại…" khi [retrying]).
class OfflineState extends StatefulWidget {
  const OfflineState({
    super.key,
    required this.onRetry,
    this.retrying = false,
    this.compact = false,
  });
  final VoidCallback? onRetry;
  final bool retrying;
  final bool compact;

  @override
  State<OfflineState> createState() => _OfflineStateState();
}

class _OfflineStateState extends State<OfflineState> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.2;
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
    final k = widget.compact ? 0.65 : 1.0;
    return StateView(
      compact: widget.compact,
      art: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Đèn pha chập chờn: tối phần lớn thời gian, loé hai lần mỗi chu kỳ
            final t = _c.value;
            final on = (t > 0.18 && t < 0.22) || (t > 0.60 && t < 0.64);
            return CustomPaint(
              size: Size(170 * k, 190 * k),
              painter: _FloodlightPainter(on ? 0.9 : 0.15),
            );
          },
        ),
      ),
      title: 'Mất điện sân rồi!',
      message: 'Không có kết nối mạng. Kiểm tra Wi-Fi hoặc 4G rồi thử lại. Kèo và lịch đã tải vẫn xem được.',
      actions: [
        LimeButton(
          label: widget.retrying ? 'Đang thử lại…' : 'Thử lại',
          loading: widget.retrying,
          expand: false,
          onPressed: widget.onRetry,
        ),
      ],
    );
  }
}

class _FloodlightPainter extends CustomPainter {
  _FloodlightPainter(this.lit);
  final double lit;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 170;
    Rect r(double x, double y, double w, double h) => Rect.fromLTWH(x * k, y * k, w * k, h * k);
    // chùm sáng
    final beam = Path()
      ..moveTo(60 * k, 60 * k)
      ..lineTo(20 * k, 190 * k)
      ..lineTo(150 * k, 190 * k)
      ..lineTo(110 * k, 60 * k)
      ..close();
    canvas.drawPath(beam, Paint()..color = const Color(0xFFFFFDE8).withValues(alpha: lit * 0.4));
    // cột
    canvas.drawRect(r(83, 56, 4, 134), Paint()..color = const Color(0xFF3A4A44));
    // bóng bóng
    final box = RRect.fromRectAndRadius(r(45, 20, 80, 40), Radius.circular(8 * k));
    canvas.drawRRect(box, Paint()..color = const Color(0xFF20302A));
    canvas.drawRRect(
      box,
      Paint()
        ..color = const Color(0xFF3A4A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * k,
    );
    for (final x in [62.0, 85.0, 108.0]) {
      canvas.drawCircle(
        Offset(x * k, 40 * k),
        9 * k,
        Paint()..color = const Color(0xFFFFFDE8).withValues(alpha: lit),
      );
    }
    canvas.drawOval(r(25, 182, 120, 8), Paint()..color = AppColors.surfaceCard);
  }

  @override
  bool shouldRepaint(covariant _FloodlightPainter old) => old.lit != lit;
}

/// "Thẻ đỏ cho hệ thống!": lỗi máy chủ. Hiện mã lỗi + giờ, nút "Báo lỗi" (nếu có [onReport]) và "Thử lại".
class ErrorState extends StatefulWidget {
  const ErrorState({
    super.key,
    required this.onRetry,
    this.retrying = false,
    this.code = 500,
    this.message = 'Có lỗi khi tải dữ liệu. Đội kỹ thuật đã được báo. Bạn thử lại sau ít phút nhé.',
    this.onReport,
    this.compact = false,
  });
  final VoidCallback? onRetry;
  final bool retrying;

  /// Mã lỗi hiện dưới mô tả ("Mã lỗi 500 · 14:32"); null thì ẩn
  final int? code;
  final String message;
  final VoidCallback? onReport;
  final bool compact;

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  final _at = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 100.0 : 150.0;
    return StateView(
      compact: widget.compact,
      art: ExcludeSemantics(
        child: SizedBox(
          width: size + 40,
          height: size + 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size + 20,
                height: size + 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x59FF5A5F), Color(0x00FF5A5F)],
                    stops: [0, 0.7],
                  ),
                ),
              ),
              RotationTransition(
                turns: Tween<double>(
                  begin: -10 / 360,
                  end: 8 / 360,
                ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                alignment: const Alignment(0, 0.8),
                child: Image.asset('assets/images/icon3d_red_card.webp', width: size, height: size),
              ),
            ],
          ),
        ),
      ),
      title: 'Thẻ đỏ cho hệ thống!',
      message: widget.message,
      extra: widget.code == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mã lỗi ${widget.code} · ${DateFormat('HH:mm').format(_at)}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textDim),
              ),
            ),
      actions: [
        if (widget.onReport != null)
          GhostButton(label: 'Báo lỗi', expand: false, onPressed: widget.onReport),
        LimeButton(
          label: widget.retrying ? 'Đang thử lại…' : 'Thử lại',
          loading: widget.retrying,
          expand: false,
          onPressed: widget.onRetry,
        ),
      ],
    );
  }
}

/// "Sân đang vắng": danh sách rỗng. [primaryLabel]/[secondaryLabel] tuỳ màn
/// (vd "Đăng kèo" / "Sửa bộ lọc"); không truyền thì không hiện nút.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = 'Sân đang vắng',
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  });
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 130.0 : 210.0;
    return StateView(
      compact: compact,
      art: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 22 : 32),
          child: Image.asset(
            'assets/images/state_empty.jpg',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: title,
      message: message,
      actions: [
        if (secondaryLabel != null)
          GhostButton(label: secondaryLabel!, expand: false, onPressed: onSecondary),
        if (primaryLabel != null)
          LimeButton(label: primaryLabel!, expand: false, onPressed: onPrimary),
      ],
    );
  }
}

/// Khối xám nhấp nháy (skeleton) cho chỗ đang tải. Tắt nhấp nháy khi bật "giảm chuyển động".
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 14, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 0.4;
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
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final x = 1.2 - 2.4 * _c.value; // trượt từ phải sang trái
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.circle ? null : BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: const [AppColors.surfaceCard, Color(0xFF1B3527), AppColors.surfaceCard],
              stops: const [0, 0.45, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Đang tải: quả bóng quay + dòng chữ + vài khối skeleton (đúng màn 34 "Đang tải").
/// [compact] chỉ hiện bóng + chữ (dùng trong danh sách / vùng nhỏ).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Đang tải…', this.compact = false});
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        const BallMark(size: 34, spin: true, period: Duration(milliseconds: 2400)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      label: label,
      liveRegion: true,
      child: compact
          ? Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: header)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 14),
                  const Skeleton(height: 260, radius: 28),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Skeleton(width: 44, height: 44, circle: true),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(widthFactor: 0.6, child: Skeleton()),
                            SizedBox(height: 8),
                            FractionallySizedBox(widthFactor: 0.4, child: Skeleton(height: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Skeleton(height: 120, radius: 22),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Expanded(child: Skeleton(height: 110, radius: 20)),
                      SizedBox(width: 10),
                      Expanded(child: Skeleton(height: 110, radius: 20)),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
