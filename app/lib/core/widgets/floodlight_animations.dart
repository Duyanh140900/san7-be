import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Hai tia sáng đèn pha quét rất chậm trên nền tối.
class FloodlightBeams extends StatefulWidget {
  const FloodlightBeams({super.key, this.opacity = 0.22, this.child});

  final double opacity;
  final Widget? child;

  @override
  State<FloodlightBeams> createState() => _FloodlightBeamsState();
}

class _FloodlightBeamsState extends State<FloodlightBeams>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child ?? const SizedBox.expand(),
      IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            final sweep = Curves.easeInOut.transform(_controller.value) - .5;
            return Opacity(
              opacity: widget.opacity,
              child: Stack(
                children: [
                  _Beam(
                    alignment: Alignment.topLeft,
                    angle: -.22 + sweep * .16,
                  ),
                  _Beam(
                    alignment: Alignment.topRight,
                    angle: .22 - sweep * .16,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _Beam extends StatelessWidget {
  const _Beam({required this.alignment, required this.angle});
  final Alignment alignment;
  final double angle;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Transform.rotate(
      angle: angle,
      alignment: alignment == Alignment.topLeft
          ? Alignment.topLeft
          : Alignment.topRight,
      child: Container(
        width: 240,
        height: 460,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xB8D9FF8B), Color(0x00C8FF2E)],
          ),
        ),
      ),
    ),
  );
}

/// Ảnh có chuyển động Ken Burns nhẹ; URL lỗi hoặc trống sẽ trở về asset.
class KenBurnsImage extends StatefulWidget {
  const KenBurnsImage({
    super.key,
    required this.fallbackAsset,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.duration = const Duration(seconds: 12),
  });

  final String fallbackAsset;
  final String? imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final Duration duration;

  @override
  State<KenBurnsImage> createState() => _KenBurnsImageState();
}

class _KenBurnsImageState extends State<KenBurnsImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.scale(
        scale: MediaQuery.disableAnimationsOf(context)
            ? 1
            : 1 + _controller.value * .07,
        child: child,
      ),
      child: widget.imageUrl == null || widget.imageUrl!.isEmpty
          ? Image.asset(
              widget.fallbackAsset,
              fit: widget.fit,
              alignment: widget.alignment,
            )
          : Image.network(
              widget.imageUrl!,
              fit: widget.fit,
              alignment: widget.alignment,
              errorBuilder: (_, _, _) => Image.asset(
                widget.fallbackAsset,
                fit: widget.fit,
                alignment: widget.alignment,
              ),
            ),
    ),
  );
}

/// Cho nội dung xuất hiện theo nhịp, mỗi [index] trễ thêm 60ms.
class StaggeredRise extends StatefulWidget {
  const StaggeredRise({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
  });
  final int index;
  final Widget child;
  final double offset;

  @override
  State<StaggeredRise> createState() => _StaggeredRiseState();
}

class _StaggeredRiseState extends State<StaggeredRise> {
  var _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: _visible || reduced ? 1 : 0,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible || reduced
            ? Offset.zero
            : Offset(0, widget.offset / 100),
        duration: reduced
            ? Duration.zero
            : Duration(milliseconds: 420 + widget.index * 60),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Dải sáng trắng-lime quét định kỳ qua CTA và thẻ vé.
class ShineSweep extends StatefulWidget {
  const ShineSweep({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(seconds: 4),
  });
  final Widget child;
  final bool enabled;
  final Duration duration;

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) || !widget.enabled
        ? _controller.stop()
        : _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ShineSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      if (widget.enabled && !MediaQuery.disableAnimationsOf(context))
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, _) => FractionalTranslation(
                  translation: Offset(-1.6 + _controller.value * 3.2, 0),
                  child: Transform.rotate(
                    angle: -.28,
                    child: const FractionallySizedBox(
                      widthFactor: .28,
                      heightFactor: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0x70FFFFFF),
                              Color(0x00C8FF2E),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class FloatingMotion extends StatefulWidget {
  const FloatingMotion({
    super.key,
    required this.child,
    this.distance = 6,
    this.duration = const Duration(milliseconds: 2200),
  });
  final Widget child;
  final double distance;
  final Duration duration;
  @override
  State<FloatingMotion> createState() => _FloatingMotionState();
}

class _FloatingMotionState extends State<FloatingMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) => Transform.translate(
      offset: Offset(
        0,
        -widget.distance * Curves.easeInOut.transform(_controller.value),
      ),
      child: child,
    ),
  );
}

/// Vòng sóng radar cho trạng thái đang tìm, bản đồ và quyền vị trí.
class RadarRipple extends StatefulWidget {
  const RadarRipple({
    super.key,
    this.size = 120,
    this.color = AppColors.lime,
    this.child,
  });
  final double size;
  final Color color;
  final Widget? child;
  @override
  State<RadarRipple> createState() => _RadarRippleState();
}

class _RadarRippleState extends State<RadarRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context)
        ? _controller.stop()
        : _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (final delay in [.0, .33, .66])
            _RippleRing(
              value: (_controller.value + delay) % 1,
              color: widget.color,
            ),
          if (widget.child != null) widget.child!,
        ],
      ),
    ),
  );
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({required this.value, required this.color});
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: (1 - value) * .65,
    child: FractionallySizedBox(
      widthFactor: .2 + value * .8,
      heightFactor: .2 + value * .8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.2),
        ),
      ),
    ),
  );
}

/// Nhịp phát sáng dịu cho LIVE, badge nóng và CTA quan trọng.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    this.color = AppColors.lime,
    this.enabled = true,
  });
  final Widget child;
  final Color color;
  final bool enabled;
  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) || !widget.enabled
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) => DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(
              alpha: .12 + _controller.value * .28,
            ),
            blurRadius: 8 + _controller.value * 14,
            spreadRadius: _controller.value * 2,
          ),
        ],
      ),
      child: child,
    ),
  );
}
