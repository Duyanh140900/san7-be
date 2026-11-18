import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'brand_mark.dart';

/// Một tin trong dải LIVE. [live] = true thêm chấm cam nhấp nháy đầu tin.
class TickerItem {
  const TickerItem(this.text, {this.color = AppColors.textMuted, this.live = false});
  final String text;
  final Color color;
  final bool live;
}

/// Dải LIVE chạy chữ ngang, lặp vô hạn (màn 01). Nền #0A1A11, viền trên/dưới mờ.
/// Người dùng bật "giảm chuyển động" thì đứng yên (vẫn cuộn tay được).
/// Rỗng → không hiện gì (SizedBox.shrink).
class LiveTicker extends StatefulWidget {
  const LiveTicker({super.key, required this.items, this.speed = 40});
  final List<TickerItem> items;

  /// Tốc độ chạy, dp mỗi giây
  final double speed;

  @override
  State<LiveTicker> createState() => _LiveTickerState();
}

class _LiveTickerState extends State<LiveTicker> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration t) {
    final dt = (t - _last).inMicroseconds / 1e6;
    _last = t;
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.offset + widget.speed * dt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce || widget.items.isEmpty) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Tin nhanh: ${items.map((e) => e.text).join('. ')}',
      excludeSemantics: true,
      child: Container(
        height: 38,
        decoration: const BoxDecoration(
          color: AppColors.surfaceStrip,
          border: Border.symmetric(horizontal: BorderSide(color: Color(0x0FFFFFFF))),
        ),
        child: ListView.builder(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, i) {
            final it = items[i % items.length];
            return Padding(
              padding: const EdgeInsets.only(right: 28),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (it.live) ...[const LiveDot(), const SizedBox(width: 8)],
                    Text(
                      it.text,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: it.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
