import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_field_row.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/money_input.dart';
import '../../../core/widgets/pills.dart';
import '../../../core/widgets/pitch_art.dart';
import '../../pitches/pitches_providers.dart';
import '../../posts/data/posts_repository.dart';
import '../../posts/posts_providers.dart';
import '../../posts/presentation/post_widgets.dart';

/// Màn 2 · Đăng kèo: tìm đối, tuyển người, pass sân. Hẹn lịch và ảnh/video có ở M5.
class PostCreateScreen extends ConsumerStatefulWidget {
  const PostCreateScreen({super.key});

  @override
  ConsumerState<PostCreateScreen> createState() => _PostCreateScreenState();
}

const _ratios = [
  (50, 'Chia đôi'),
  (40, 'Thua trả 60%'),
  (30, 'Thua trả 70%'),
  (20, 'Thua trả 80%'),
];

class _PostCreateScreenState extends ConsumerState<PostCreateScreen> {
  static const _types = [
    PostTypeValue.findOpponent,
    PostTypeValue.recruit,
    PostTypeValue.passPitch,
  ];

  PostTypeValue _type = PostTypeValue.findOpponent;
  String? _teamId;
  late DateTime _date; // ngày theo giờ VN
  TimeOfDay _start = const TimeOfDay(hour: 19, minute: 0);
  int _durationMin = 90;
  TeamLevelValue? _level;
  PostDealValue _deal = PostDealValue.split;
  int _ratioWin = 40;
  final Set<PositionValue> _positions = {};
  final _pitch = TextEditingController();
  final _price = TextEditingController();
  final _players = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  /// Sân đã đặt được chọn để đăng kèo (chỉ với kèo tìm đối).
  BookingDto? _booking;

  @override
  void initState() {
    super.initState();
    final now = Fmt.vn(DateTime.now());
    _date = DateTime.utc(now.year, now.month, now.day);
    // Đã quá 19:00 thì gợi ý ngày mai
    if (now.hour >= 18) _date = _date.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _pitch.dispose();
    _price.dispose();
    _players.dispose();
    _body.dispose();
    super.dispose();
  }

  DateTime get _startUtc => DateTime.utc(
    _date.year,
    _date.month,
    _date.day,
    _start.hour,
    _start.minute,
  ).subtract(const Duration(hours: 7));

  MyTeamDto? _team(List<MyTeamDto> teams) {
    if (teams.isEmpty) return null;
    return teams.firstWhere((t) => t.teamId == _teamId, orElse: () => teams.first);
  }

  int? get _priceValue {
    final v = MoneyInputFormatter.parse(_price.text);
    return v > 0 ? v : null;
  }

  Future<void> _pickTeam(List<MyTeamDto> teams) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in teams)
              ListTile(
                title: Text(t.name),
                subtitle: Text('${t.area} · ${Labels.level(t.level)}'),
                onTap: () => Navigator.pop(ctx, t.teamId),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _teamId = picked);
  }

  Future<void> _pickDate() async {
    final now = Fmt.vn(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 60)),
      locale: const Locale('vi'),
    );
    if (picked != null) setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _customRatio() async {
    final v = await showRatioDialog(context, title: 'Tỷ lệ tuỳ chỉnh', initial: _ratioWin);
    if (v != null) setState(() => _ratioWin = v);
  }

  Future<void> _pickBooking(List<BookingDto> options) async {
    final picked = await showModalBottomSheet<BookingDto>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in options)
              ListTile(
                title: Text('${b.pitch.name} · sân ${b.courtNo}'),
                subtitle: Text(Fmt.eventTime(b.startAt, b.endAt)),
                onTap: () => Navigator.pop(ctx, b),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _booking = picked;
      if (_price.text.isEmpty) _price.text = MoneyInputFormatter.formatAmount(picked.price);
    });
  }

  Future<void> _save(MyTeamDto team) async {
    final booking = _type == PostTypeValue.findOpponent ? _booking : null;
    final start = booking?.startAt ?? _startUtc;
    if (booking == null && start.isBefore(DateTime.now())) {
      return showToast(context, 'Giờ đá đã qua, chọn giờ khác', type: ToastType.warning);
    }
    if (_type == PostTypeValue.passPitch && _pitch.text.trim().isEmpty) {
      return showToast(context, 'Nhập tên sân muốn pass', type: ToastType.warning);
    }
    final players = int.tryParse(_players.text);
    if (_type == PostTypeValue.recruit && _positions.isEmpty && players == null) {
      return showToast(context, 'Chọn vị trí hoặc số người cần', type: ToastType.warning);
    }
    final level = _level ?? (team.level as TeamLevelKnown).value;
    final isFind = _type == PostTypeValue.findOpponent;
    final body = CreatePostDto(
      type: PostTypeKnown(_type),
      startAt: start,
      endAt: booking?.endAt ?? start.add(Duration(minutes: _durationMin)),
      pitchName: booking != null || _pitch.text.trim().isEmpty ? null : _pitch.text.trim(),
      bookingId: booking?.id,
      level: TeamLevelKnown(level),
      deal: isFind ? PostDealKnown(_deal) : null,
      ratioWin: isFind && _deal == PostDealValue.split ? _ratioWin : null,
      ratioLose: isFind && _deal == PostDealValue.split ? 100 - _ratioWin : null,
      pitchPrice: _type == PostTypeValue.recruit ? null : _priceValue,
      positions: _type == PostTypeValue.recruit
          ? [for (final p in _positions) PositionKnown(p)]
          : null,
      playersNeeded: _type == PostTypeValue.recruit ? players : null,
      body: _body.text.trim().isEmpty ? null : _body.text.trim(),
    );
    setState(() => _saving = true);
    PostDto? created;
    final ok = await runAction(
      context,
      () async => created = await ref.read(postsRepositoryProvider).create(team.teamId, body),
      success: 'Đã đăng kèo lên Bảng tin',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(feedProvider);
      ref.invalidate(teamBookingsProvider(team.teamId));
      context.pop();
      if (created != null) context.push(Routes.post(created!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(managedTeamsProvider);
    final team = _team(teams);
    if (team == null) return const _NoTeam();

    final level =
        _level ?? (team.level is TeamLevelKnown ? (team.level as TeamLevelKnown).value : null);
    final dateLabel = '${Fmt.weekday(_startUtc)}, ${Fmt.dayMonth(_startUtc)}';
    final end = _startUtc.add(Duration(minutes: _durationMin));
    final split = feeSplit(_priceValue, _ratioWin, 100 - _ratioWin);
    final customRatio = !_ratios.any((r) => r.$1 == _ratioWin);
    final booking = _type == PostTypeValue.findOpponent ? _booking : null;
    final bookable = _type == PostTypeValue.findOpponent
        ? [
            for (final b
                in ref.watch(teamBookingsProvider(team.teamId)).value ?? const <BookingDto>[])
              if (b.status == BookingStatus.confirmed && b.postId == null) b,
          ]
        : const <BookingDto>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(saving: _saving, onSave: () => _save(team)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  Segmented(
                    labels: [
                      for (final t in _types) Labels.postTypes.firstWhere((e) => e.$1 == t).$2,
                    ],
                    index: _types.indexOf(_type),
                    onChanged: (i) => setState(() => _type = _types[i]),
                  ),
                  const SizedBox(height: 22),
                  FormCaption(_type == PostTypeValue.passPitch ? 'Khung giờ' : 'Trận đấu'),
                  FormGroup(
                    children: [
                      _ValueRow(
                        label: 'Đội của bạn',
                        value: team.name,
                        onTap: teams.length > 1 ? () => _pickTeam(teams) : null,
                      ),
                      if (booking == null) ...[
                        _ValueRow(label: 'Ngày', value: dateLabel, onTap: _pickDate),
                        _ValueRow(
                          label: 'Giờ',
                          value: '${Fmt.time(_startUtc)} – ${Fmt.time(end)}',
                          onTap: _pickTime,
                        ),
                      ],
                    ],
                  ),
                  if (booking == null) ...[
                    const SizedBox(height: 10),
                    PillSelector<int>(
                      options: const [60, 90, 120],
                      selected: _durationMin,
                      labelOf: (m) => m == 90 ? '1 tiếng 30' : '${m ~/ 60} tiếng',
                      onSelected: (m) => setState(() => _durationMin = m),
                      padding: 0,
                    ),
                  ],
                  const SizedBox(height: 22),
                  const FormCaption('Sân'),
                  if (booking != null)
                    _BookedPitchCard(
                      booking: booking,
                      onClear: () => setState(() => _booking = null),
                    )
                  else ...[
                    if (bookable.isNotEmpty) ...[
                      _PickBookedRow(onTap: () => _pickBooking(bookable)),
                      const SizedBox(height: 10),
                    ],
                    FormFieldRow(
                      controller: _pitch,
                      hint: _type == PostTypeValue.passPitch
                          ? 'Tên sân muốn pass, ví dụ Sân Phúc La, sân 2'
                          : 'Tên sân (để trống nếu chưa có)',
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(120)],
                    ),
                  ],
                  if (_type != PostTypeValue.recruit) ...[
                    const SizedBox(height: 10),
                    FormFieldRow(
                      label: _type == PostTypeValue.passPitch ? 'Giá nhượng' : 'Tiền sân',
                      controller: _price,
                      hint: '0',
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MoneyInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      trailing: const Text('đ', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const FormCaption('Trình độ'),
                  PillSelector<TeamLevelValue>(
                    options: [for (final l in Labels.levels) l.$1],
                    selected: level,
                    labelOf: (v) => Labels.levels.firstWhere((e) => e.$1 == v).$2,
                    onSelected: (v) => setState(() => _level = v),
                    padding: 0,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                    child: Text(
                      'TBY: trung bình yếu · TB: trung bình · TBK: trung bình khá',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  if (_type == PostTypeValue.findOpponent) ...[
                    const SizedBox(height: 22),
                    const FormCaption('Kèo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in Labels.deals)
                          Pill(
                            label: d.$2,
                            selected: _deal == d.$1,
                            onTap: () => setState(() => _deal = d.$1),
                          ),
                      ],
                    ),
                    if (_deal == PostDealValue.split) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tỷ lệ chia',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              'Đội thắng – Đội thua',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final r in _ratios)
                              _RatioChip(
                                title: '${r.$1} – ${100 - r.$1}',
                                caption: r.$2,
                                selected: _ratioWin == r.$1,
                                onTap: () => setState(() => _ratioWin = r.$1),
                              ),
                            _RatioChip(
                              title: customRatio ? '$_ratioWin – ${100 - _ratioWin}' : 'Tuỳ chỉnh',
                              caption: 'Tự nhập',
                              selected: customRatio,
                              onTap: _customRatio,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (split != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Sân ${Fmt.money(_priceValue!)}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            Text.rich(
                              TextSpan(
                                style: const TextStyle(fontSize: 14),
                                children: [
                                  const TextSpan(text: 'Thắng '),
                                  TextSpan(
                                    text: Fmt.money(split.win),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const TextSpan(text: ' · Thua '),
                                  TextSpan(
                                    text: Fmt.money(split.lose),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (_type == PostTypeValue.recruit) ...[
                    const SizedBox(height: 22),
                    const FormCaption('Vị trí cần'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in Labels.positions)
                          Pill(
                            label: p.$2,
                            selected: _positions.contains(p.$1),
                            onTap: () => setState(
                              () => _positions.contains(p.$1)
                                  ? _positions.remove(p.$1)
                                  : _positions.add(p.$1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FormFieldRow(
                      label: 'Số người cần',
                      controller: _players,
                      hint: '1',
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  const FormCaption('Lời nhắn'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.group),
                    ),
                    child: TextField(
                      controller: _body,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 16, height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: 'Ví dụ: Đội đá vui, giữ chân là chính. Có áo đồng phục xanh.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppIcon(AppIcons.info, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kèo sẽ hiện trên Bảng tin, lọc theo khu vực ${team.area}. '
                          'Đội nhận kèo cần đội trưởng hoặc phó đội bạn xác nhận.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.saving, required this.onSave});
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Row(
      children: [
        LinkButton('Huỷ', onTap: () => context.pop()),
        const Expanded(
          child: Text(
            'Đăng kèo',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        saving
            ? const SizedBox(
                width: 40,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : GestureDetector(
                onTap: onSave,
                child: const SizedBox(
                  height: AppSizes.tapTarget,
                  child: Center(
                    child: Text(
                      'Đăng',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}

/// Hàng nhãn trái, giá trị xám + mũi tên phải (như màn 2).
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textSecondary),
          ],
        ],
      ),
    ),
  );
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({
    required this.title,
    required this.caption,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.primarySoftText : AppColors.text;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppColors.primary : AppColors.pillBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? AppColors.primarySoftText : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoTeam extends StatelessWidget {
  const _NoTeam();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(children: [LinkButton('Đóng', onTap: () => context.pop())]),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppCard(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chỉ đội trưởng hoặc phó đội được đăng kèo',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Tạo đội mới hoặc nhờ đội trưởng trao quyền phó đội cho bạn trong tab Đội.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Hàng "Chọn từ sân đã đặt" (chỉ hiện khi đội có lượt đặt sắp tới chưa gắn kèo).
class _PickBookedRow extends StatelessWidget {
  const _PickBookedRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FormGroup(
    children: [_ValueRow(label: 'Chọn từ sân đã đặt', value: '', onTap: onTap)],
  );
}

/// Sân đã đặt được chọn: giờ và sân lấy theo lượt đặt.
class _BookedPitchCard extends StatelessWidget {
  const _BookedPitchCard({required this.booking, required this.onClear});
  final BookingDto booking;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        const PitchArt(size: 56, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${booking.pitch.name} · sân ${booking.courtNo}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                Fmt.eventTime(booking.startAt, booking.endAt),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Text(
                'Đã đặt · giờ và sân lấy theo lượt đặt',
                style: TextStyle(fontSize: 12, color: AppColors.greenSoftText),
              ),
            ],
          ),
        ),
        LinkButton('Bỏ chọn', onTap: onClear),
      ],
    ),
  );
}
