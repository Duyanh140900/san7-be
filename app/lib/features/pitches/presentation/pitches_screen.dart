import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/pitch_art.dart';
import '../pitches_providers.dart';
import 'pitch_detail_screen.dart';
import 'pitch_widgets.dart';

/// Tâm Hà Nội: nơi map nhìn khi chưa có vị trí và chưa có sân nào.
const _hanoi = LatLng(21.0285, 105.8542);

/// "Sân bóng Phúc La" → "Phúc La"
String shortPitchName(String name) =>
    name.replaceFirst(RegExp(r'^Sân( bóng)?\\s+', caseSensitive: false), '');

/// Màn 04 · Bản đồ đặt sân: ghim sân v2, thanh tìm kiếm + bộ lọc, thẻ sân đang chọn với khung giờ nhanh.
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
      backgroundColor: AppColors.surfaceCard,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final t in ['', ...times])
              ListTile(
                title: Text(
                  t.isEmpty ? 'Mọi giờ' : t,
                  style: const TextStyle(color: AppColors.textMain),
                ),
                trailing: (t.isEmpty ? cur == null : cur == t)
                    ? const Icon(Icons.check, color: AppColors.lime)
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
              ? const ColoredBox(color: AppColors.night)
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
                    const SimpleAttributionWidget(
                      source: Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(color: AppColors.textDim, fontSize: 10),
                      ),
                      alignment: Alignment.bottomLeft,
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
                            height: 48,
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
        // Tìm kiếm và bộ lọc v2
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SearchBox(
                      controller: _q,
                      onSubmitted: (v) => _search.update(
                        (s) => v.trim().isEmpty ? s.copyWith(clearQ: true) : s.copyWith(q: v.trim()),
                      ),
                      onClear: () {
                        _q.clear();
                        _search.update((s) => s.copyWith(clearQ: true));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: _list ? 'Xem bản đồ' : 'Xem danh sách',
                    child: Material(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        onTap: () => setState(() => _list = !_list),
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Center(
                            child: Icon(
                              _list ? Icons.map_outlined : Icons.tune,
                              color: AppColors.ink,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  children: [
                    _V2Chip(
                      label: Fmt.relativeDay(search.day),
                      selected: true,
                      onTap: _pickDay,
                    ),
                    const SizedBox(width: 8),
                    _V2Chip(
                      label: search.at ?? 'Mọi giờ',
                      selected: search.at != null,
                      onTap: () => _pickTime(pitches),
                    ),
                    const SizedBox(width: 8),
                    _V2Chip(
                      label: 'Sân 7',
                      selected: false,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _V2Chip(
                      label: 'Có đèn',
                      selected: search.light,
                      onTap: () => _search.update((s) => s.copyWith(light: !s.light)),
                    ),
                    if (me != null) ...[
                      const SizedBox(width: 8),
                      _V2Chip(
                        label: 'Gần tôi',
                        selected: search.useLocation,
                        onTap: () => _search.update((s) => s.copyWith(useLocation: !s.useLocation)),
                      ),
                      if (search.useLocation) ...[
                        const SizedBox(width: 8),
                        _V2Chip(
                          label: 'Dưới 1 km',
                          selected: search.within1km,
                          onTap: () => _search.update((s) => s.copyWith(within1km: !s.within1km)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (result.isLoading)
          Positioned(
            top: top + 116,
            left: 0,
            right: 0,
            child: const Center(child: _Busy()),
          ),
        if (_list)
          Positioned.fill(
            top: top + 116,
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
              bottom: 310,
              child: _RoundButton(
                icon: Icons.my_location,
                label: 'Về vị trí của tôi',
                onTap: () => _map.move(me, 14.5),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
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

class _V2Chip extends StatelessWidget {
  const _V2Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.lime : AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: AppColors.line),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.ink : AppColors.textMain,
            ),
          ),
        ),
      ),
    ),
  );
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onSubmitted, required this.onClear});
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    height: 50,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
      boxShadow: const [
        BoxShadow(
          color: Colors.black45,
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        const AppIcon(AppIcons.search, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            style: const TextStyle(fontSize: 15, color: AppColors.textMain),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Tìm sân, khu vực...',
              hintStyle: TextStyle(color: AppColors.textDim, fontSize: 15),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (_, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                ),
        ),
      ],
    ),
  );
}

/// Ghim sân v2: nền lime khi chọn, nền trắng hoặc xám khi chưa chọn.
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
        : '${shortPitchName(pitch.name)} · ${full ? 'hết' : pitch.freeSlots}';

    final bg = selected
        ? AppColors.lime
        : (full ? const Color(0xFF2A3530) : const Color(0xFFF2F7F3));
    final fg = selected
        ? AppColors.ink
        : (full ? const Color(0xFF8FA597) : const Color(0xFF06110B));

    return Semantics(
      button: true,
      label: 'Sân $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: selected ? AppColors.lime.withValues(alpha: 0.45) : Colors.black45,
                    blurRadius: selected ? 16 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.ink
                          : (full ? AppColors.disabled : AppColors.grass),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 2, height: 6, color: bg),
          ],
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
        color: AppColors.home.withValues(alpha: 0.20),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.home,
          border: Border.all(color: AppColors.textMain, width: 3),
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
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: AppColors.lime, size: 22),
      ),
    ),
  );
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.line),
    ),
    child: const BallMark(size: 22, spin: true),
  );
}

/// Thẻ nổi hiển thị sân đang chọn và các khung giờ trống (Màn 04).
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
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            const Center(
              child: Text(
                'Lỗi tải danh sách sân',
                style: TextStyle(color: AppColors.card, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Thử lại', style: TextStyle(color: AppColors.lime)),
              ),
            ),
          ] else if (p == null) ...[
            _EmptyHint(onShowAll: nearby ? onShowAll : null),
          ] else ...[
            GestureDetector(
              onTap: () => onOpen(p),
              behavior: HitTestBehavior.opaque,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      const PitchArt(size: 96, radius: 20),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            p.freeSlots == 0 ? 'HẾT SÂN' : '${p.freeSlots} TRỐNG',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
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
                        Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            p.district,
                            if (p.distanceM != null) Fmt.distance(p.distanceM!),
                          ].join(' · '),
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        AmenityTags(p.amenities, small: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (quick.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Hết khung giờ trống trong ngày này',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textDim),
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
            LimeButton(
              label: p.minPrice == null
                  ? 'Xem sân & đặt'
                  : 'Xem sân & đặt · ${Fmt.money(p.minPrice!)}',
              onPressed: () => onOpen(p),
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
    child: Material(
      color: selected ? AppColors.lime : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: selected ? null : Border.all(color: AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.ink : AppColors.textMain,
            ),
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
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thử đổi ngày, giờ hoặc bỏ bớt bộ lọc.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        if (onShowAll != null)
          TextButton(
            onPressed: onShowAll,
            child: const Text('Xem tất cả sân', style: TextStyle(color: AppColors.lime)),
          ),
      ],
    ),
  );
}

/// Chế độ danh sách của màn 04.
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onToggle,
            icon: const AppIcon(AppIcons.pin, size: 16, color: AppColors.lime),
            label: const Text('Bản đồ', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (result.hasError && !result.isLoading)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('Không tải được danh sách sân', style: TextStyle(color: AppColors.card)),
              TextButton(onPressed: onRetry, child: const Text('Thử lại', style: TextStyle(color: AppColors.lime))),
            ],
          ),
        )
      else if (pitches.isEmpty && !result.isLoading)
        _EmptyHint(onShowAll: onShowAll)
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: AppColors.line),
        ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [p.district, if (p.distanceM != null) Fmt.distance(p.distanceM!)].join(' · '),
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.freeSlots == 0
                        ? 'Hết khung giờ trống'
                        : '${p.freeSlots} khung trống${p.minPrice == null ? '' : ' · từ ${Fmt.money(p.minPrice!)}'}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.freeSlots == 0 ? AppColors.textDim : AppColors.lime,
                    ),
                  ),
                ],
              ),
            ),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
