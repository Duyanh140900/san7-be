import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/pitch_art.dart';
import '../pitches_providers.dart';
import 'pitch_detail_screen.dart';

/// Tâm Hà Nội: nơi map nhìn khi chưa có vị trí và chưa có sân nào.
const _hanoi = LatLng(21.0285, 105.8542);

/// "Sân bóng Phúc La" → "Phúc La"
String shortPitchName(String name) =>
    name.replaceFirst(RegExp(r'^Sân( bóng)?\s+', caseSensitive: false), '');

/// Màn 3 · Bản đồ đặt sân: ghim sân, bộ lọc, thẻ sân đang chọn với khung giờ nhanh.
class PitchesScreen extends ConsumerStatefulWidget {
  const PitchesScreen({super.key});

  @override
  ConsumerState<PitchesScreen> createState() => _PitchesScreenState();
}

class _PitchesScreenState extends ConsumerState<PitchesScreen> with WidgetsBindingObserver {
  final _map = MapController();
  final _q = TextEditingController();
  bool _ready = false;
  bool _centered = false;
  bool _list = false;

  /// Zoom xa: ghim chỉ còn chấm + số trống để khỏi chồng lên nhau.
  bool _compact = false;
  String? _selectedId;
  DateTime? _slot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Quay lại app (vd từ Cài đặt sau khi bật quyền vị trí): thử lấy vị trí lại nếu chưa có.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ref.read(userLocationProvider).value == null) {
      _centered = false;
      ref.invalidate(userLocationProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _q.dispose();
    _map.dispose();
    super.dispose();
  }

  PitchSearchNotifier get _search => ref.read(pitchSearchProvider.notifier);

  /// Đưa camera tới vị trí của tôi, hoặc ôm trọn các sân tìm được.
  void _recenter(LatLng? me, List<PitchDto> pitches) {
    if (!_ready || _centered) return;
    if (me != null) {
      _centered = true;
      _map.move(me, 14);
    } else if (pitches.isNotEmpty) {
      _centered = true;
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: [for (final p in pitches) LatLng(p.lat.toDouble(), p.lng.toDouble())],
          padding: const EdgeInsets.fromLTRB(48, 190, 48, 340),
          maxZoom: 14,
        ),
      );
    }
  }

  Future<void> _pickDay() async {
    final s = ref.read(pitchSearchProvider);
    final v = Fmt.vn(s.day);
    final today = Fmt.vn(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(v.year, v.month, v.day),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day).add(const Duration(days: 30)),
      locale: const Locale('vi'),
    );
    if (picked == null) return;
    final day = DateTime.utc(
      picked.year,
      picked.month,
      picked.day,
    ).subtract(const Duration(hours: 7));
    _search.update((s) => s.copyWith(day: day));
  }

  Future<void> _pickTime(List<PitchDto> pitches) async {
    final times = {
      for (final p in pitches)
        for (final s in p.slots) Fmt.time(s.startAt),
    }.toList()..sort();
    final cur = ref.read(pitchSearchProvider).at;
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in ['', ...times])
              ListTile(
                title: Text(t.isEmpty ? 'Mọi giờ' : t),
                trailing: (t.isEmpty ? cur == null : cur == t)
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _search.update((s) => picked.isEmpty ? s.copyWith(clearAt: true) : s.copyWith(at: picked));
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(pitchSearchProvider);
    final result = ref.watch(pitchListProvider);
    final me = ref.watch(userLocationProvider).value;
    final pitches = result.value ?? const <PitchDto>[];
    final selected = pitches.isEmpty
        ? null
        : pitches.firstWhere((p) => p.id == _selectedId, orElse: () => pitches.first);

    // Camera: chỉ chỉnh một lần khi có dữ liệu đầu tiên
    if (_ready && !_centered && (me != null || pitches.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _recenter(me, pitches);
      });
    }

    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(
          child: _list
              ? const ColoredBox(color: AppColors.background)
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: me ?? _hanoi,
                    initialZoom: 13,
                    minZoom: 9,
                    maxZoom: 18,
                    onPositionChanged: (camera, _) {
                      final compact = camera.zoom < 12.5;
                      if (compact != _compact) setState(() => _compact = compact);
                    },
                    onMapReady: () {
                      _ready = true;
                      if (mounted) setState(() {});
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'vn.san7.app',
                    ),
                    if (me != null)
                      MarkerLayer(
                        markers: [Marker(point: me, width: 44, height: 44, child: const _MyDot())],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final p in pitches)
                          Marker(
                            point: LatLng(p.lat.toDouble(), p.lng.toDouble()),
                            width: 190,
                            height: 40,
                            child: Center(
                              child: _Pin(
                                pitch: p,
                                selected: p.id == selected?.id,
                                compact: _compact,
                                onTap: () => setState(() {
                                  _selectedId = p.id;
                                  _slot = null;
                                }),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
        // Tìm kiếm và bộ lọc
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Column(
            children: [
              _SearchBox(
                controller: _q,
                onSubmitted: (v) => _search.update(
                  (s) => v.trim().isEmpty ? s.copyWith(clearQ: true) : s.copyWith(q: v.trim()),
                ),
                onClear: () {
                  _q.clear();
                  _search.update((s) => s.copyWith(clearQ: true));
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    FilterPill(
                      elevated: true,
                      label: Fmt.relativeDay(search.day),
                      selected: true,
                      onTap: _pickDay,
                    ),
                    FilterPill(
                      elevated: true,
                      label: search.at ?? 'Mọi giờ',
                      selected: search.at != null,
                      onTap: () => _pickTime(pitches),
                    ),
                    FilterPill(
                      elevated: true,
                      label: 'Có đèn',
                      selected: search.light,
                      onTap: () => _search.update((s) => s.copyWith(light: !s.light)),
                    ),
                    if (me != null) ...[
                      FilterPill(
                        elevated: true,
                        label: 'Gần tôi',
                        selected: search.useLocation,
                        onTap: () => _search.update((s) => s.copyWith(useLocation: !s.useLocation)),
                      ),
                      if (search.useLocation)
                        FilterPill(
                          elevated: true,
                          label: 'Dưới 1 km',
                          selected: search.within1km,
                          onTap: () => _search.update((s) => s.copyWith(within1km: !s.within1km)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (result.isLoading)
          Positioned(
            top: top + 112,
            left: 0,
            right: 0,
            child: const Center(child: _Busy()),
          ),
        if (_list)
          Positioned.fill(
            top: top + 112,
            child: _PitchList(
              pitches: pitches,
              result: result,
              date: search.day,
              onOpen: (p) => _open(p, null),
              onToggle: () => setState(() => _list = false),
              onRetry: () => ref.invalidate(pitchListProvider),
              onShowAll: () => _search.update((s) => s.copyWith(useLocation: false)),
            ),
          )
        else ...[
          if (me != null)
            Positioned(
              right: 16,
              bottom: 330,
              child: _RoundButton(
                icon: Icons.my_location,
                label: 'Về vị trí của tôi',
                onTap: () => _map.move(me, 14.5),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Sheet(
              count: pitches.length,
              nearby: me != null && search.useLocation,
              pitch: selected,
              error: result.hasError && !result.isLoading ? result.error : null,
              slot: _slot,
              onSlot: (s) => setState(() => _slot = s),
              onList: () => setState(() => _list = true),
              onOpen: (p) => _open(p, _slot),
              onRetry: () => ref.invalidate(pitchListProvider),
              onShowAll: () => _search.update((s) => s.copyWith(useLocation: false)),
            ),
          ),
        ],
      ],
    );
  }

  void _open(PitchDto p, DateTime? slot) {
    final day = ref.read(pitchSearchProvider).day;
    context.push(
      Routes.pitch(p.id),
      extra: PitchDetailArgs(day: day, slot: slot),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmitted, required this.onClear});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        const AppIcon(AppIcons.search, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Tìm sân, quận, đường…',
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                ),
        ),
      ],
    ),
  );
}

/// Ghim sân: chấm xanh (còn giờ) hoặc xám (hết), chọn thì nền xanh dương.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.pitch,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final PitchDto pitch;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = pitch.freeSlots == 0;
    final label = compact
        ? (full ? '–' : '${pitch.freeSlots}')
        : '${shortPitchName(pitch.name)} · ${full ? 'hết' : '${pitch.freeSlots} trống'}';
    return Semantics(
      button: true,
      label: 'Sân $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: const [
              BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? Colors.white : (full ? AppColors.disabled : AppColors.green),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyDot extends StatelessWidget {
  const _MyDot();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    ),
  );
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
    child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

/// Thẻ phía dưới: số sân, sân đang chọn, khung giờ nhanh, nút xem & đặt.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.count,
    required this.nearby,
    required this.pitch,
    required this.error,
    required this.slot,
    required this.onSlot,
    required this.onList,
    required this.onOpen,
    required this.onRetry,
    required this.onShowAll,
  });
  final int count;
  final bool nearby;
  final PitchDto? pitch;
  final Object? error;
  final DateTime? slot;
  final ValueChanged<DateTime?> onSlot;
  final VoidCallback onList;
  final ValueChanged<PitchDto> onOpen;
  final VoidCallback onRetry;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final p = pitch;
    final quick = p == null
        ? const <PitchSlotDto>[]
        : p.slots.where((s) => s.available).take(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.pillBorder,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  nearby ? '$count sân gần bạn' : '$count sân',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              LinkButton('Danh sách', onTap: onList),
            ],
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    'Không tải được danh sách sân',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  LinkButton('Thử lại', onTap: onRetry),
                ],
              ),
            )
          else if (p == null)
            _EmptyHint(onShowAll: nearby ? onShowAll : null)
          else ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => onOpen(p),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const PitchArt(size: 64, radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            p.district,
                            if (p.distanceM != null) Fmt.distance(p.distanceM!),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            for (final a in p.amenities.take(2)) Labels.amenity(a),
                            '${p.courtsCount} sân 7',
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.greenSoftText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (quick.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Hết khung giờ trống trong ngày này',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              )
            else
              Row(
                children: [
                  for (final (i, s) in quick.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _QuickSlot(
                        label: Fmt.time(s.startAt),
                        selected: slot == s.startAt,
                        onTap: () => onSlot(slot == s.startAt ? null : s.startAt),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => onOpen(p), child: const Text('Xem sân & đặt')),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Bản đồ © OpenStreetMap',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickSlot extends StatelessWidget {
  const _QuickSlot({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.pillBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onShowAll});
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Column(
      children: [
        const Text(
          'Không có sân phù hợp bộ lọc',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thử đổi ngày, giờ hoặc bỏ bớt bộ lọc.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        if (onShowAll != null) LinkButton('Xem tất cả sân (không theo vị trí)', onTap: onShowAll),
      ],
    ),
  );
}

/// Chế độ danh sách của màn 3.
class _PitchList extends StatelessWidget {
  const _PitchList({
    required this.pitches,
    required this.result,
    required this.date,
    required this.onOpen,
    required this.onToggle,
    required this.onRetry,
    required this.onShowAll,
  });
  final List<PitchDto> pitches;
  final AsyncValue<List<PitchDto>> result;
  final DateTime date;
  final ValueChanged<PitchDto> onOpen;
  final VoidCallback onToggle;
  final VoidCallback onRetry;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${pitches.length} sân · ${Fmt.relativeDay(date)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          LinkButton('Bản đồ', onTap: onToggle),
        ],
      ),
      const SizedBox(height: 8),
      if (result.hasError && !result.isLoading)
        AppCard(
          child: Column(
            children: [
              const Text('Không tải được danh sách sân'),
              LinkButton('Thử lại', onTap: onRetry),
            ],
          ),
        )
      else if (pitches.isEmpty && !result.isLoading)
        AppCard(child: _EmptyHint(onShowAll: onShowAll))
      else
        for (final p in pitches) ...[
          _PitchTile(pitch: p, onTap: () => onOpen(p)),
          const SizedBox(height: 12),
        ],
    ],
  );
}

class _PitchTile extends StatelessWidget {
  const _PitchTile({required this.pitch, required this.onTap});
  final PitchDto pitch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pitch;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const PitchArt(size: 64, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [p.district, if (p.distanceM != null) Fmt.distance(p.distanceM!)].join(' · '),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.freeSlots == 0
                        ? 'Hết khung giờ trống'
                        : '${p.freeSlots} khung trống${p.minPrice == null ? '' : ' · từ ${Fmt.money(p.minPrice!)}'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.freeSlots == 0 ? AppColors.textSecondary : AppColors.greenSoftText,
                    ),
                  ),
                ],
              ),
            ),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
