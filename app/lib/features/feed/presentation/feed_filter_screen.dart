import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../posts/data/posts_repository.dart';
import '../../posts/posts_providers.dart';

/// Màn 30 · Bộ lọc kèo nâng cao (sheet/screen).
class FeedFilterScreen extends ConsumerStatefulWidget {
  const FeedFilterScreen({super.key});

  @override
  ConsumerState<FeedFilterScreen> createState() => _FeedFilterScreenState();
}

class _FeedFilterScreenState extends ConsumerState<FeedFilterScreen> {
  late FeedFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = ref.read(feedFilterProvider);
  }

  void _reset() {
    setState(() {
      _filter = const FeedFilter();
    });
  }

  void _apply() {
    ref.read(feedFilterProvider.notifier).apply(_filter);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final countAsync = ref.watch(feedCountProvider(_filter));
    final count = countAsync.value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surfaceCard,
      body: SafeArea(
        child: Column(
          children: [
            // Drag bar & Header
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.lineStrong,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      SquareIconButton(
                        tooltip: 'Đóng',
                        onPressed: () => context.pop(),
                        child: const AppIcon(AppIcons.close, size: 20, color: AppColors.textMain),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lọc kèo',
                        style: AppText.display(24, color: AppColors.textMain),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.lime,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    child: const Text('Đặt lại'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // 1. Loại bài
                  _sectionHeader('LOẠI BÀI'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _filter.type == null,
                        onTap: () => setState(() => _filter = _filter.withBasic(type: () => null)),
                      ),
                      for (final t in Labels.postTypes)
                        _FilterChip(
                          label: t.$2,
                          selected: _filter.type == t.$1,
                          onTap: () => setState(
                            () => _filter = _filter.withBasic(
                              type: () => _filter.type == t.$1 ? null : t.$1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Khoảng cách
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader('KHOẢNG CÁCH'),
                      Text(
                        _filter.maxKm == null ? 'Không giới hạn' : '≤ ${_filter.maxKm!.toInt()} km',
                        style: AppText.score(18, color: AppColors.lime),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.lime,
                      inactiveTrackColor: AppColors.surfaceHigh,
                      thumbColor: AppColors.lime,
                      overlayColor: AppColors.lime.withValues(alpha: 0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      min: 1,
                      max: 15,
                      divisions: 14,
                      value: (_filter.maxKm ?? 15).toDouble(),
                      onChanged: (val) {
                        setState(() {
                          _filter = FeedFilter(
                            type: _filter.type,
                            area: _filter.area,
                            q: _filter.q,
                            maxKm: val == 15 ? null : val.round(),
                            date: _filter.date,
                            timeSlot: _filter.timeSlot,
                            levelMin: _filter.levelMin,
                            levelMax: _filter.levelMax,
                            ratioType: _filter.ratioType,
                            minRating: _filter.minRating,
                            hideCancellers: _filter.hideCancellers,
                          );
                        });
                      },
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 km', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
                      Text('15 km (mặc định)', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Ngày đá
                  _sectionHeader('NGÀY ĐÁ'),
                  const SizedBox(height: 8),
                  _DayPicker(
                    selectedDate: _filter.date,
                    onSelected: (dateStr) {
                      setState(() {
                        _filter = FeedFilter(
                          type: _filter.type,
                          area: _filter.area,
                          q: _filter.q,
                          maxKm: _filter.maxKm,
                          date: _filter.date == dateStr ? null : dateStr,
                          timeSlot: _filter.timeSlot,
                          levelMin: _filter.levelMin,
                          levelMax: _filter.levelMax,
                          ratioType: _filter.ratioType,
                          minRating: _filter.minRating,
                          hideCancellers: _filter.hideCancellers,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 4. Khung giờ
                  _sectionHeader('KHUNG GIỜ'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SlotCard(
                          title: 'Sáng',
                          time: '06:00–12:00',
                          selected: _filter.timeSlot == PostsFeedTimeSlotValue.morning,
                          onTap: () => _setTimeSlot(PostsFeedTimeSlotValue.morning),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SlotCard(
                          title: 'Chiều',
                          time: '12:00–17:30',
                          selected: _filter.timeSlot == PostsFeedTimeSlotValue.afternoon,
                          onTap: () => _setTimeSlot(PostsFeedTimeSlotValue.afternoon),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SlotCard(
                          title: 'Tối',
                          time: '17:30–23:00',
                          selected: _filter.timeSlot == PostsFeedTimeSlotValue.evening,
                          onTap: () => _setTimeSlot(PostsFeedTimeSlotValue.evening),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. Trình độ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader('TRÌNH ĐỘ · CHỌN KHOẢNG'),
                      if (_filter.levelMin != null || _filter.levelMax != null)
                        Text(
                          _levelLabel(_filter.levelMin, _filter.levelMax),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lime,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _LevelRangeSelector(
                    min: _filter.levelMin,
                    max: _filter.levelMax,
                    onChanged: (min, max) {
                      setState(() {
                        _filter = FeedFilter(
                          type: _filter.type,
                          area: _filter.area,
                          q: _filter.q,
                          maxKm: _filter.maxKm,
                          date: _filter.date,
                          timeSlot: _filter.timeSlot,
                          levelMin: min,
                          levelMax: max,
                          ratioType: _filter.ratioType,
                          minRating: _filter.minRating,
                          hideCancellers: _filter.hideCancellers,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // 6. Kèo & tỷ lệ
                  _sectionHeader('KÈO & TỶ LỆ'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _filter.ratioType == null,
                        onTap: () => _setRatio(null),
                      ),
                      _FilterChip(
                        label: '50–50',
                        selected: _filter.ratioType == PostDealValue.split,
                        onTap: () => _setRatio(PostDealValue.split),
                      ),
                      _FilterChip(
                        label: 'Thua trả',
                        selected: _filter.ratioType == PostDealValue.loserPays,
                        onTap: () => _setRatio(PostDealValue.loserPays),
                      ),
                      _FilterChip(
                        label: 'Giao lưu',
                        selected: _filter.ratioType == PostDealValue.friendly,
                        onTap: () => _setRatio(PostDealValue.friendly),
                      ),
                      _FilterChip(
                        label: 'Nước ngọt',
                        selected: _filter.ratioType == PostDealValue.drinks,
                        onTap: () => _setRatio(PostDealValue.drinks),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 7. Uy tín & Ẩn đội huỷ kèo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Chỉ đội uy tín từ 4,5 ★',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                          subtitle: const Text(
                            'Được nhiều đối thủ đánh giá tốt',
                            style: TextStyle(fontSize: 12, color: AppColors.textDim),
                          ),
                          value: _filter.minRating != null && _filter.minRating! >= 4.5,
                          activeThumbColor: AppColors.lime,
                          onChanged: (on) {
                            setState(() {
                              _filter = FeedFilter(
                                type: _filter.type,
                                area: _filter.area,
                                q: _filter.q,
                                maxKm: _filter.maxKm,
                                date: _filter.date,
                                timeSlot: _filter.timeSlot,
                                levelMin: _filter.levelMin,
                                levelMax: _filter.levelMax,
                                ratioType: _filter.ratioType,
                                minRating: on ? 4.5 : null,
                                hideCancellers: _filter.hideCancellers,
                              );
                            });
                          },
                        ),
                        const Divider(height: 1, color: AppColors.line),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Ẩn đội hay huỷ kèo',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                          subtitle: const Text(
                            'Loại bỏ đội có tỷ lệ huỷ kèo cao',
                            style: TextStyle(fontSize: 12, color: AppColors.textDim),
                          ),
                          value: _filter.hideCancellers,
                          activeThumbColor: AppColors.lime,
                          onChanged: (on) {
                            setState(() {
                              _filter = FeedFilter(
                                type: _filter.type,
                                area: _filter.area,
                                q: _filter.q,
                                maxKm: _filter.maxKm,
                                date: _filter.date,
                                timeSlot: _filter.timeSlot,
                                levelMin: _filter.levelMin,
                                levelMax: _filter.levelMax,
                                ratioType: _filter.ratioType,
                                minRating: _filter.minRating,
                                hideCancellers: on,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: LimeButton(
                label: countAsync.isLoading ? 'Đang tính kèo...' : 'Xem $count kèo phù hợp',
                onPressed: _apply,
                expand: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) => Text(
    label,
    style: AppText.label.copyWith(color: AppColors.textMuted),
  );

  void _setTimeSlot(PostsFeedTimeSlotValue slot) {
    setState(() {
      _filter = FeedFilter(
        type: _filter.type,
        area: _filter.area,
        q: _filter.q,
        maxKm: _filter.maxKm,
        date: _filter.date,
        timeSlot: _filter.timeSlot == slot ? null : slot,
        levelMin: _filter.levelMin,
        levelMax: _filter.levelMax,
        ratioType: _filter.ratioType,
        minRating: _filter.minRating,
        hideCancellers: _filter.hideCancellers,
      );
    });
  }

  void _setRatio(PostDealValue? deal) {
    setState(() {
      _filter = FeedFilter(
        type: _filter.type,
        area: _filter.area,
        q: _filter.q,
        maxKm: _filter.maxKm,
        date: _filter.date,
        timeSlot: _filter.timeSlot,
        levelMin: _filter.levelMin,
        levelMax: _filter.levelMax,
        ratioType: _filter.ratioType == deal ? null : deal,
        minRating: _filter.minRating,
        hideCancellers: _filter.hideCancellers,
      );
    });
  }

  String _levelLabel(TeamLevelValue? min, TeamLevelValue? max) {
    if (min == null && max == null) return 'Mọi trình độ';
    if (min != null && max != null) {
      if (min == max) return Labels.level(TeamLevelKnown(min));
      return '${Labels.level(TeamLevelKnown(min))} – ${Labels.level(TeamLevelKnown(max))}';
    }
    if (min != null) return 'Từ ${Labels.level(TeamLevelKnown(min))}';
    return 'Đến ${Labels.level(TeamLevelKnown(max!))}';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.pill),
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.lime : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: selected ? AppColors.lime : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.ink : AppColors.textMain,
        ),
      ),
    ),
  );
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.title,
    required this.time,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String time;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.tile),
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.lime : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: selected ? AppColors.lime : AppColors.line),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.ink : AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.ink.withValues(alpha: 0.8) : AppColors.textDim,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.selectedDate, required this.onSelected});
  final String? selectedDate;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.add(Duration(days: i));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final label = i == 0
          ? 'Hôm nay'
          : i == 1
          ? 'Ngày mai'
          : 'T${d.weekday + 1 == 8 ? 'CN' : d.weekday + 1} ${d.day}/${d.month}';
      return (dateStr, label);
    });

    return SizedBox(
      height: AppSizes.tapTarget,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final (dateStr, label) in days) ...[
            _FilterChip(
              label: label,
              selected: selectedDate == dateStr,
              onTap: () => onSelected(dateStr),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _LevelRangeSelector extends StatelessWidget {
  const _LevelRangeSelector({required this.min, required this.max, required this.onChanged});
  final TeamLevelValue? min;
  final TeamLevelValue? max;
  final void Function(TeamLevelValue? min, TeamLevelValue? max) onChanged;

  static const _levels = [
    (TeamLevelValue.yeu, 'Y'),
    (TeamLevelValue.tby, 'Y+'),
    (TeamLevelValue.tb, 'TB'),
    (TeamLevelValue.tbk, 'TB+'),
    (TeamLevelValue.gioi, 'K'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.tapTarget,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _levels.length; i++) ...[
            if (i > 0) Container(width: 1, color: AppColors.line),
            Expanded(
              child: _LevelCell(
                level: _levels[i].$1,
                label: _levels[i].$2,
                isSelected: _isInRange(_levels[i].$1),
                onTap: () => _pickLevel(_levels[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isInRange(TeamLevelValue l) {
    if (min == null && max == null) return false;
    final idx = _levels.indexWhere((e) => e.$1 == l);
    final minIdx = min == null ? 0 : _levels.indexWhere((e) => e.$1 == min);
    final maxIdx = max == null ? _levels.length - 1 : _levels.indexWhere((e) => e.$1 == max);
    return idx >= minIdx && idx <= maxIdx;
  }

  void _pickLevel(TeamLevelValue l) {
    if (min == null && max == null) {
      onChanged(l, l);
    } else if (min != null && max != null && min == max) {
      final idx = _levels.indexWhere((e) => e.$1 == l);
      final curIdx = _levels.indexWhere((e) => e.$1 == min);
      if (idx == curIdx) {
        onChanged(null, null);
      } else if (idx < curIdx) {
        onChanged(l, min);
      } else {
        onChanged(min, l);
      }
    } else {
      onChanged(l, l);
    }
  }
}

class _LevelCell extends StatelessWidget {
  const _LevelCell({
    required this.level,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final TeamLevelValue level;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      color: isSelected ? AppColors.lime : Colors.transparent,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isSelected ? AppColors.ink : AppColors.textMain,
        ),
      ),
    ),
  );
}
