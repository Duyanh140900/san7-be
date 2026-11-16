import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/money_input.dart';
import '../../attendance/presentation/event_widgets.dart' show eventKindLabel;
import '../../team/team_providers.dart';
import '../data/funds_repository.dart';

/// Mở màn Thêm khoản với giá trị điền sẵn (ví dụ ghi nhận quỹ tháng).
class AddFundTxArgs {
  const AddFundTxArgs({this.type = FundTypeValue.income, this.period, this.amount});
  const AddFundTxArgs.dues({required String this.period, required int this.amount})
    : type = FundTypeValue.income;

  final FundTypeValue type;
  final String? period;
  final int? amount;
}

const _incomeCategories = ['Đội đối chuyển tiền sân', 'Tài trợ', 'Khác'];
const _expenseCategories = ['Tiền sân', 'Nước uống', 'Áo đấu', 'Bóng', 'Liên hoan', 'Khác'];

/// Thêm khoản thu / chi / phạt (màn 20). Chỉ đội trưởng và thủ quỹ mở được.
class AddFundTxScreen extends ConsumerStatefulWidget {
  const AddFundTxScreen({super.key, this.args = const AddFundTxArgs()});
  final AddFundTxArgs args;

  @override
  ConsumerState<AddFundTxScreen> createState() => _AddFundTxScreenState();
}

class _AddFundTxScreenState extends ConsumerState<AddFundTxScreen> {
  late FundTypeValue _type = widget.args.type;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _incomeCategory;
  bool _isDues = false;
  String _expenseCategory = _expenseCategories.first;
  String? _fineRuleId; // null = "Khác"
  final Set<String> _payers = {};
  final Set<String> _fined = {};
  String? _spender;
  String? _eventId;
  bool _finePaid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.args.period != null) _isDues = true;
    if (widget.args.amount != null) {
      _amount.text = MoneyInputFormatter.formatAmount(widget.args.amount!);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _amountValue => MoneyInputFormatter.parse(_amount.text);

  void _setAmount(int v) => setState(() => _amount.text = MoneyInputFormatter.formatAmount(v));

  Future<void> _save(String teamId, int monthlyDue, List<FineRuleDto> rules) async {
    final amount = _amountValue;
    if (amount <= 0) return showToast(context, 'Nhập số tiền', type: ToastType.warning);
    final CreateFundTxDto body;
    switch (_type) {
      case FundTypeValue.income:
        if (_isDues && _payers.isEmpty) return showToast(context, 'Chọn người đóng quỹ', type: ToastType.warning);
        final period = widget.args.period ?? Fmt.currentPeriod();
        body = CreateFundTxDto(
          type: FundTypeKnown(FundTypeValue.income),
          amount: amount,
          category: _isDues ? 'Quỹ ${Fmt.periodLabel(period)}' : (_incomeCategory ?? 'Khác'),
          memberIds: _payers.toList(),
          period: _isDues ? period : null,
          note: _noteOrNull,
        );
      case FundTypeValue.expense:
        body = CreateFundTxDto(
          type: FundTypeKnown(FundTypeValue.expense),
          amount: amount,
          category: _expenseCategory,
          memberIds: [?_spender],
          eventId: _eventId,
          note: _noteOrNull,
        );
      case FundTypeValue.fine:
        if (_fined.isEmpty) return showToast(context, 'Chọn người bị phạt', type: ToastType.warning);
        final rule = rules.where((r) => r.id == _fineRuleId).firstOrNull;
        body = CreateFundTxDto(
          type: FundTypeKnown(FundTypeValue.fine),
          amount: amount,
          category: rule?.name ?? 'Khác',
          memberIds: _fined.toList(),
          eventId: _eventId,
          paid: _finePaid,
          note: _noteOrNull,
        );
    }
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => ref.read(fundsRepositoryProvider).create(teamId, body),
      success: 'Đã lưu khoản',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.invalidate(fundSummaryProvider(teamId));
      context.pop();
    }
  }

  String? get _noteOrNull => _note.text.trim().isEmpty ? null : _note.text.trim();

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const Scaffold();
    final team = ref.watch(teamDetailProvider(teamId)).value;
    final members = ref.watch(membersProvider(teamId)).value?.active ?? const <MemberDto>[];
    final events = ref.watch(upcomingEventsProvider(teamId)).value ?? const <EventSummaryDto>[];
    final rules = ref.watch(fineRulesProvider(teamId)).value ?? const <FineRuleDto>[];
    final monthlyDue = team?.monthlyDue ?? 0;

    final (amountLabel, amountColor) = switch (_type) {
      FundTypeValue.income => (
        _payers.length > 1 ? 'Thu từ ${_payers.length} người · mỗi người' : 'Số tiền thu',
        const Color(0xFF1F7A35),
      ),
      FundTypeValue.expense => ('Số tiền chi', AppColors.text),
      FundTypeValue.fine => (
        _fined.length > 1 ? 'Tiền phạt · mỗi người' : 'Tiền phạt',
        AppColors.red,
      ),
    };
    final count = switch (_type) {
      FundTypeValue.income => _payers.length,
      FundTypeValue.fine => _fined.length,
      FundTypeValue.expense => 1,
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            FormHeader(
              title: 'Thêm khoản',
              saving: _saving,
              onSave: () => _save(teamId, monthlyDue, rules),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  Segmented(
                    labels: const ['Thu', 'Chi', 'Phạt'],
                    index: FundTypeValue.values.indexOf(_type),
                    onChanged: (i) => setState(() => _type = FundTypeValue.values[i]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    amountLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  TextField(
                    controller: _amount,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MoneyInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.2,
                      color: amountColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: 'đ',
                      suffixStyle: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  if (count > 1 && _amountValue > 0)
                    Text(
                      'Tổng ${Fmt.money(_amountValue * count)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  const SizedBox(height: 20),
                  ...switch (_type) {
                    FundTypeValue.income => _incomeSection(members, monthlyDue),
                    FundTypeValue.expense => _expenseSection(members, events),
                    FundTypeValue.fine => _fineSection(members, events, rules),
                  },
                  const SizedBox(height: 20),
                  const FormCaption('Ghi chú'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(minHeight: 50),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.group),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _note,
                      inputFormatters: [LengthLimitingTextInputFormatter(200)],
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(hintText: 'Không bắt buộc'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _incomeSection(List<MemberDto> members, int monthlyDue) {
    final duesLabel = 'Quỹ ${Fmt.periodLabel(widget.args.period ?? Fmt.currentPeriod())}';
    final perPerson = _amountValue > 0 ? ' · ${Fmt.money(_amountValue)} / người' : '';
    return [
      const FormCaption('Loại thu'),
      _ChipWrap(
        children: [
          if (monthlyDue > 0 || _isDues)
            _Chip(
              label: duesLabel,
              selected: _isDues,
              onTap: () {
                setState(() {
                  _isDues = true;
                  _incomeCategory = null;
                });
                if (monthlyDue > 0) _setAmount(monthlyDue);
              },
            ),
          for (final c in _incomeCategories)
            _Chip(
              label: c,
              selected: !_isDues && _incomeCategory == c,
              onTap: () => setState(() {
                _isDues = false;
                _incomeCategory = c;
              }),
            ),
        ],
      ),
      const SizedBox(height: 20),
      FormCaption('Người nộp · chọn nhiều$perPerson'),
      _PeoplePicker(
        members: members,
        selected: _payers,
        onToggle: (id) =>
            setState(() => _payers.contains(id) ? _payers.remove(id) : _payers.add(id)),
      ),
    ];
  }

  List<Widget> _expenseSection(List<MemberDto> members, List<EventSummaryDto> events) {
    final spender = members.where((m) => m.userId == _spender).firstOrNull;
    final event = events.where((e) => e.id == _eventId).firstOrNull;
    return [
      const FormCaption('Hạng mục'),
      _ChipWrap(
        children: [
          for (final c in _expenseCategories)
            _Chip(
              label: c,
              selected: _expenseCategory == c,
              onTap: () => setState(() => _expenseCategory = c),
            ),
        ],
      ),
      const SizedBox(height: 20),
      FormGroup(
        children: [
          FormTapRow(
            label: 'Người chi',
            value: spender?.name ?? 'Chọn',
            onTap: () async {
              final id = await _pickMember(members, 'Người chi');
              if (id != null) setState(() => _spender = id.isEmpty ? null : id);
            },
          ),
          FormTapRow(
            label: 'Gắn với lịch',
            value: event != null ? '${event.title} · ${Fmt.dayMonth(event.startAt)}' : 'Không',
            onTap: () => _pickEvent(events),
          ),
        ],
      ),
    ];
  }

  List<Widget> _fineSection(
    List<MemberDto> members,
    List<EventSummaryDto> events,
    List<FineRuleDto> rules,
  ) {
    final event = events.where((e) => e.id == _eventId).firstOrNull;
    return [
      const FormCaption('Người bị phạt'),
      _PeoplePicker(
        members: members,
        selected: _fined,
        onToggle: (id) => setState(() => _fined.contains(id) ? _fined.remove(id) : _fined.add(id)),
      ),
      const SizedBox(height: 20),
      const FormCaption('Lý do · theo luật đội'),
      _ChipWrap(
        children: [
          for (final r in rules)
            _Chip(
              label: '${r.name} · ${Fmt.money(r.amount)}',
              selected: _fineRuleId == r.id,
              onTap: () {
                setState(() => _fineRuleId = r.id);
                _setAmount(r.amount);
              },
            ),
          _Chip(
            label: 'Khác',
            selected: _fineRuleId == null,
            onTap: () => setState(() => _fineRuleId = null),
          ),
        ],
      ),
      if (rules.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Chưa có luật phạt. Thêm ở nút ••• trong Tổng quan đội.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      const SizedBox(height: 20),
      FormGroup(
        children: [
          FormTapRow(
            label: 'Lịch / trận',
            value: event != null ? '${event.title} · ${Fmt.dayMonth(event.startAt)}' : 'Không',
            onTap: () => _pickEvent(events),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Đã nộp', style: TextStyle(fontSize: 16)),
                      Text(
                        'Bật để cộng ngay vào quỹ',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _finePaid,
                  activeTrackColor: AppColors.greenBright,
                  onChanged: (v) => setState(() => _finePaid = v),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  /// Chọn một thành viên. Trả về '' nếu chọn "Không ai".
  Future<String?> _pickMember(List<MemberDto> members, String title) {
    final auth = ref.read(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ListTile(title: const Text('Không ai'), onTap: () => Navigator.pop(sheet, '')),
              for (final m in members)
                ListTile(
                  leading: Avatar(name: m.name, url: m.avatarUrl, size: 36),
                  title: Text(m.userId == myId ? '${m.name} (bạn)' : m.name),
                  onTap: () => Navigator.pop(sheet, m.userId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickEvent(List<EventSummaryDto> events) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Gắn với lịch', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ListTile(title: const Text('Không'), onTap: () => Navigator.pop(sheet, '')),
            for (final e in events)
              ListTile(
                title: Text(e.title),
                subtitle: Text('${eventKindLabel(e.kind)} · ${Fmt.eventTime(e.startAt, e.endAt)}'),
                onTap: () => Navigator.pop(sheet, e.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) setState(() => _eventId = id.isEmpty ? null : id);
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: children);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: selected ? AppColors.primary : AppColors.pillBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primarySoftText : AppColors.text,
        ),
      ),
    ),
  );
}

/// Hàng avatar cuộn ngang, chọn nhiều (viền xanh khi chọn).
class _PeoplePicker extends StatelessWidget {
  const _PeoplePicker({required this.members, required this.selected, required this.onToggle});
  final List<MemberDto> members;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: members.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final m = members[i];
            final on = selected.contains(m.userId);
            final first = m.name.trim().split(RegExp(r'\s+')).last;
            return Semantics(
              button: true,
              selected: on,
              label: m.name,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onToggle(m.userId),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: on ? AppColors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Avatar(name: m.name, url: m.avatarUrl, size: 40),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
