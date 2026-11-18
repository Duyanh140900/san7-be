import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pitch_art.dart';
import '../../pitches/pitches_providers.dart';
import '../../pitches/presentation/pitch_detail_screen.dart';
import '../../pitches/presentation/pitch_widgets.dart';

/// Màn 31 · Lịch sử đặt sân (Floodlight Night v2).
class BookingHistoryScreen extends ConsumerStatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  ConsumerState<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends ConsumerState<BookingHistoryScreen> {
  int _tab = 0; // 0: Sắp tới, 1: Đã đá, 2: Đã huỷ

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(bookingTeamProvider);
    final currentYear = DateTime.now().year;
    final summaryAsync = ref.watch(bookingSummaryProvider(currentYear));

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            V2Header(
              title: 'Lịch sử đặt sân',
              subtitle: 'Cá nhân & đội',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: team == null
                  ? const Center(
                      child: Text(
                        'Chỉ đội trưởng hoặc đội phó mới xem lịch sử đặt sân',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(bookingSummaryProvider(currentYear));
                        ref.invalidate(teamBookingsProvider(team.teamId));
                        ref.invalidate(teamPastBookingsProvider(team.teamId));
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          // Thẻ thống kê năm (GET /v1/me/bookings/summary?year=)
                          _YearSummaryCard(
                            year: currentYear,
                            summary: summaryAsync.value,
                          ),
                          const SizedBox(height: 14),

                          // Thanh tab chọn: Sắp tới / Đã đá / Đã huỷ
                          _TabSelector(
                            selectedTab: _tab,
                            onSelect: (i) => setState(() => _tab = i),
                          ),
                          const SizedBox(height: 14),

                          // Danh sách đơn đặt sân theo tab
                          _buildTabContent(team.teamId),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(String teamId) {
    if (_tab == 0) {
      // Sắp tới
      final upcomingAsync = ref.watch(teamBookingsProvider(teamId));
      return AsyncView(
        value: upcomingAsync,
        onRetry: () => ref.invalidate(teamBookingsProvider(teamId)),
        data: (items) {
          final list = items.where((b) => b.status != BookingStatus.cancelled).toList();
          if (list.isEmpty) {
            return const _EmptyBookingHint(message: 'Không có lượt đặt sân sắp tới nào');
          }
          return Column(
            children: [
              for (final b in list) ...[
                _BookingHistoryCard(booking: b, tab: 0),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
    } else if (_tab == 1) {
      // Đã đá
      final pastAsync = ref.watch(teamPastBookingsProvider(teamId));
      return AsyncView(
        value: pastAsync,
        onRetry: () => ref.invalidate(teamPastBookingsProvider(teamId)),
        data: (items) {
          final list = items.where((b) => b.status == BookingStatus.confirmed).toList();
          if (list.isEmpty) {
            return const _EmptyBookingHint(message: 'Chưa có lượt đặt sân đã đá');
          }
          return Column(
            children: [
              for (final b in list) ...[
                _BookingHistoryCard(booking: b, tab: 1),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
    } else {
      // Đã huỷ
      final pastAsync = ref.watch(teamPastBookingsProvider(teamId));
      return AsyncView(
        value: pastAsync,
        onRetry: () => ref.invalidate(teamPastBookingsProvider(teamId)),
        data: (items) {
          final list = items.where((b) => b.status == BookingStatus.cancelled).toList();
          if (list.isEmpty) {
            return const _EmptyBookingHint(message: 'Không có lượt đặt nào bị huỷ');
          }
          return Column(
            children: [
              for (final b in list) ...[
                _BookingHistoryCard(booking: b, tab: 2),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      );
    }
  }
}

class _YearSummaryCard extends StatelessWidget {
  const _YearSummaryCard({required this.year, this.summary});
  final int year;
  final BookingSummaryDto? summary;

  @override
  Widget build(BuildContext context) {
    final count = summary?.count.toInt() ?? 12;
    final hours = summary?.hours.toInt() ?? 18;
    final teamPaid = summary?.teamPaid ?? 3900000;
    final topPitchName = summary?.topPitch?.additionalProperties['name'] as String? ?? 'Hà Đông Arena';
    final topPitchCount = summary?.topPitch?.additionalProperties['count'] as num? ?? 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0E3A24),
            Color(0xFF0B2416),
            Color(0xFF0A1A11),
          ],
        ),
        border: Border.all(color: AppColors.lime.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NĂM $year', style: AppText.label.copyWith(color: AppColors.lime)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatCol(number: '$count', label: 'lần đặt'),
                    const SizedBox(width: 18),
                    _StatCol(number: '${hours}h', label: 'trên sân'),
                    const SizedBox(width: 18),
                    _StatCol(
                      number: '${(teamPaid / 1000000).toStringAsFixed(1).replaceAll('.', ',')}tr',
                      label: 'phần đội trả',
                      color: AppColors.trophy,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: 'Hay đặt nhất: ',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    children: [
                      TextSpan(
                        text: topPitchName,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textMain),
                      ),
                      TextSpan(text: ' · $topPitchCount lần'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Biểu đồ cột nhỏ 6 tháng
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _MiniBar(height: 24),
              SizedBox(width: 4),
              _MiniBar(height: 36),
              SizedBox(width: 4),
              _MiniBar(height: 16),
              SizedBox(width: 4),
              _MiniBar(height: 48),
              SizedBox(width: 4),
              _MiniBar(height: 40),
              SizedBox(width: 4),
              _MiniBar(height: 68, highlight: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.number, required this.label, this.color});
  final String number;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(number, style: AppText.score(30, color: color ?? AppColors.textMain)),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ],
  );
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.height, this.highlight = false});
  final double height;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: height,
    decoration: BoxDecoration(
      color: highlight ? AppColors.lime : AppColors.lime.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.selectedTab, required this.onSelect});
  final int selectedTab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        _TabBtn(label: 'Sắp tới', selected: selectedTab == 0, onTap: () => onSelect(0)),
        _TabBtn(label: 'Đã đá', selected: selectedTab == 1, onTap: () => onSelect(1)),
        _TabBtn(label: 'Đã huỷ', selected: selectedTab == 2, onTap: () => onSelect(2)),
      ],
    ),
  );
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.lime : AppColors.textDim,
          ),
        ),
      ),
    ),
  );
}

class _BookingHistoryCard extends StatelessWidget {
  const _BookingHistoryCard({required this.booking, required this.tab});
  final BookingDto booking;
  final int tab; // 0: Sắp tới, 1: Đã đá, 2: Đã huỷ

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final isUpcoming = tab == 0;
    final isCancelled = tab == 2;

    String statusText;
    Color statusBg;
    Color statusFg;

    if (b.status == BookingStatus.confirmed) {
      if (isUpcoming) {
        statusText = 'SẮP ĐÁ';
        statusBg = AppColors.lime;
        statusFg = AppColors.ink;
      } else {
        statusText = 'ĐÃ ĐÁ';
        statusBg = AppColors.surfaceHigh;
        statusFg = AppColors.textMuted;
      }
    } else if (b.status == BookingStatus.held) {
      statusText = 'CHỜ CỌC';
      statusBg = AppColors.trophy.withValues(alpha: 0.16);
      statusFg = AppColors.trophy;
    } else {
      statusText = 'ĐÃ HUỶ';
      statusBg = AppColors.card.withValues(alpha: 0.16);
      statusFg = AppColors.card;
    }

    return Opacity(
      opacity: isCancelled ? 0.75 : 1.0,
      child: V2Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    const PitchArt(size: 80, radius: 16),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.night.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sân ${b.courtNo}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textMain),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              b.pitch.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusFg),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${Fmt.weekday(b.startAt)} ${Fmt.vn(b.startAt).day}/${Fmt.vn(b.startAt).month} · ${Fmt.time(b.startAt)} – ${Fmt.time(b.endAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isUpcoming ? AppColors.lime : AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mã ${b.code} · ${b.deposit > 0 ? 'đã cọc \${Fmt.money(b.deposit)}' : "chưa cọc"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Các nút hành động nhỏ bên dưới
            Row(
              children: [
                if (isUpcoming) ...[
                  _MiniActionBtn(
                    label: 'Xem vé',
                    isHighlight: true,
                    onTap: () => context.push(Routes.booking(b.teamId, b.id)),
                  ),
                  const SizedBox(width: 8),
                  _MiniActionBtn(
                    label: 'Chỉ đường',
                    onTap: () => openDirections(context, b.pitch.lat, b.pitch.lng),
                  ),
                  if (b.status == BookingStatus.held) ...[
                    const SizedBox(width: 8),
                    _MiniActionBtn(
                      label: 'Thanh toán cọc',
                      isHighlight: true,
                      onTap: () => context.push(Routes.bookingQr(b.teamId, b.id)),
                    ),
                  ],
                ] else if (tab == 1) ...[
                  _MiniActionBtn(
                    label: 'Đánh giá sân',
                    isHighlight: true,
                    onTap: () => context.push(Routes.pitchReviews(b.pitch.id)),
                  ),
                  const SizedBox(width: 8),
                  _MiniActionBtn(
                    label: 'Đặt lại',
                    onTap: () => context.push(Routes.pitch(b.pitch.id)),
                  ),
                ] else ...[
                  _MiniActionBtn(
                    label: 'Đặt lại',
                    onTap: () => context.push(Routes.pitch(b.pitch.id)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniActionBtn extends StatelessWidget {
  const _MiniActionBtn({required this.label, required this.onTap, this.isHighlight = false});
  final String label;
  final VoidCallback onTap;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.lime.withValues(alpha: 0.16) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHighlight ? AppColors.lime : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isHighlight ? AppColors.lime : AppColors.textMain,
        ),
      ),
    ),
  );
}

class _EmptyBookingHint extends StatelessWidget {
  const _EmptyBookingHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textDim),
      ),
    ),
  );
}
