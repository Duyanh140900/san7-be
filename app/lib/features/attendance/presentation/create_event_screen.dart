import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_field_row.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/pills.dart';
import '../../team/team_providers.dart';
import '../data/events_repository.dart';

/// Tạo lịch đội: trận / đá nội bộ / sự kiện khác. Bố cục theo kiểu form của màn 20.
class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  EventKindValue _kind = EventKindValue.match;
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  final _minPlayers = TextEditingController(text: '9');
  late DateTime _date; // ngày theo giờ VN (chỉ dùng năm/tháng/ngày)
  TimeOfDay _start = const TimeOfDay(hour: 19, minute: 0);
  int _durationMin = 90;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = Fmt.vn(DateTime.now());
    _date = DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    _minPlayers.dispose();
    super.dispose();
  }

  /// Giờ VN đã chọn → thời điểm UTC.
  DateTime get _startUtc => DateTime.utc(
    _date.year,
    _date.month,
    _date.day,
    _start.hour,
    _start.minute,
  ).subtract(const Duration(hours: 7));

  String get _defaultTitle => switch (_kind) {
    EventKindValue.match => 'Trận đấu',
    EventKindValue.internal => 'Đá nội bộ',
    EventKindValue.other => 'Sự kiện đội',
  };

  Future<void> _pickDate() async {
    final now = Fmt.vn(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      locale: const Locale('vi'),
    );
    if (picked != null) setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _save() async {
    final teamId = ref.read(currentTeamIdProvider);
    if (teamId == null) return;
    final start = _startUtc;
    if (start.isBefore(DateTime.now())) return showToast(context, 'Giờ bắt đầu đã qua');
    setState(() => _saving = true);
    final title = _title.text.trim().isEmpty ? _defaultTitle : _title.text.trim();
    final ok = await runAction(
      context,
      () => ref
          .read(eventsRepositoryProvider)
          .create(
            teamId,
            CreateEventDto(
              kind: EventKindKnown(_kind),
              title: title,
              startAt: start,
              endAt: start.add(Duration(minutes: _durationMin)),
              location: _location.text.trim().isEmpty ? null : _location.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              minPlayers: int.tryParse(_minPlayers.text),
            ),
          ),
      success: 'Đã tạo lịch, anh em có thể điểm danh',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(upcomingEventsProvider(teamId));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    const kinds = [
      (EventKindValue.match, 'Trận'),
      (EventKindValue.internal, 'Đá nội bộ'),
      (EventKindValue.other, 'Khác'),
    ];
    final dateLabel = '${Fmt.weekday(_startUtc)} ${Fmt.dayMonth(_startUtc)}';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FormHeader(title: 'Tạo lịch', saving: _saving, onSave: _save),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  Segmented(
                    labels: [for (final k in kinds) k.$2],
                    index: kinds.indexWhere((k) => k.$1 == _kind),
                    onChanged: (i) => setState(() => _kind = kinds[i].$1),
                  ),
                  const SizedBox(height: 20),
                  FormFieldRow(
                    controller: _title,
                    hint: _kind == EventKindValue.match
                        ? 'Tiêu đề, ví dụ vs FC Mỹ Đình'
                        : _defaultTitle,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  ),
                  const SizedBox(height: 20),
                  FormGroup(
                    children: [
                      FormTapRow(label: 'Ngày', value: dateLabel, onTap: _pickDate),
                      FormTapRow(
                        label: 'Giờ bắt đầu',
                        value: _start.format(context),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const FormCaption('Thời lượng'),
                  PillSelector<int>(
                    options: const [60, 90, 120],
                    selected: _durationMin,
                    labelOf: (m) => m == 90 ? '1 tiếng 30' : '${m ~/ 60} tiếng',
                    onSelected: (m) => setState(() => _durationMin = m),
                  ),
                  const SizedBox(height: 20),
                  FormFieldRow(
                    controller: _location,
                    hint: 'Địa điểm, ví dụ Hà Đông Arena, sân 2',
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  ),
                  const SizedBox(height: 12),
                  FormFieldRow(
                    label: 'Tối thiểu',
                    controller: _minPlayers,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    trailing: const Text('người', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 12),
                  FormFieldRow(
                    controller: _note,
                    hint: 'Ghi chú (không bắt buộc), ví dụ tỷ lệ 40–60',
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(300)],
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
