import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/money_input.dart';
import '../../funds/data/funds_repository.dart';
import '../data/team_repository.dart';
import '../team_providers.dart';

/// Nút ••• ở Tổng quan đội: quỹ tháng, luật phạt, rời đội, đăng xuất.
Future<void> showTeamSettings(BuildContext context, TeamDetailDto team) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (_) => _TeamSettingsSheet(team: team, hostContext: context),
  );
}

class _TeamSettingsSheet extends ConsumerWidget {
  const _TeamSettingsSheet({required this.team, required this.hostContext});
  final TeamDetailDto team;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = team.myRole;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(team.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Cài đặt đội'),
          ),
          if (role.isCaptain)
            ListTile(
              title: const Text('Quỹ tháng mỗi người'),
              trailing: Text(
                team.monthlyDue > 0 ? Fmt.money(team.monthlyDue) : 'Không thu',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.pop(context);
                _editMonthlyDue(hostContext, ref);
              },
            ),
          if (role.canManageFunds)
            ListTile(
              title: const Text('Luật phạt của đội'),
              trailing: const Text('Sửa', style: TextStyle(color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet<void>(
                  context: hostContext,
                  backgroundColor: AppColors.surface,
                  isScrollControlled: true,
                  builder: (_) => _FineRulesSheet(teamId: team.id),
                );
              },
            ),
          if (!role.isCaptain)
            ListTile(
              title: const Text('Rời đội', style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(context);
                _leave(hostContext, ref);
              },
            ),
          ListTile(
            title: const Text('Đăng xuất'),
            onTap: () {
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editMonthlyDue(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(
      text: team.monthlyDue > 0 ? MoneyInputFormatter.formatAmount(team.monthlyDue) : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Quỹ tháng mỗi người'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [MoneyInputFormatter(max: 10000000)],
          decoration: const InputDecoration(hintText: '0 = không thu', suffixText: 'đ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Huỷ')),
          TextButton(
            onPressed: () => Navigator.pop(dialog, MoneyInputFormatter.parse(ctrl.text)),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(teamRepositoryProvider).update(team.id, UpdateTeamDto(monthlyDue: value)),
      success: value > 0 ? 'Quỹ tháng: ${Fmt.money(value)}/người' : 'Đã tắt quỹ tháng',
    );
    if (ok) {
      ref.invalidate(teamDetailProvider(team.id));
      ref.invalidate(fundSummaryProvider(team.id));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Rời ${team.name}?'),
        content: const Text(
          'Bạn sẽ không xem được lịch, quỹ của đội nữa. Muốn quay lại cần mã mời mới.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Ở lại')),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Rời đội')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final done = await runAction(
      context,
      () => ref.read(teamRepositoryProvider).leave(team.id),
      success: 'Đã rời ${team.name}',
    );
    if (done) await ref.read(authControllerProvider.notifier).reloadMe();
  }
}

class _FineRulesSheet extends ConsumerStatefulWidget {
  const _FineRulesSheet({required this.teamId});
  final String teamId;

  @override
  ConsumerState<_FineRulesSheet> createState() => _FineRulesSheetState();
}

class _FineRulesSheetState extends ConsumerState<_FineRulesSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final amount = MoneyInputFormatter.parse(_amount.text);
    if (name.isEmpty || amount < 1000) {
      return showToast(context, 'Nhập tên luật và số tiền (từ 1.000đ)');
    }
    final ok = await runAction(
      context,
      () => ref.read(fundsRepositoryProvider).createFineRule(widget.teamId, name, amount),
    );
    if (ok) {
      _name.clear();
      _amount.clear();
      ref.invalidate(fineRulesProvider(widget.teamId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(fineRulesProvider(widget.teamId));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Luật phạt của đội',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              AsyncView<List<FineRuleDto>>(
                value: rules,
                onRetry: () => ref.invalidate(fineRulesProvider(widget.teamId)),
                data: (list) => Column(
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Chưa có luật nào. Ví dụ: Đi muộn 50.000đ, Bỏ trận không báo 100.000đ.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    for (final r in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.name),
                        subtitle: Text(Fmt.money(r.amount)),
                        trailing: IconButton(
                          tooltip: 'Xoá luật',
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            if (await runAction(
                              context,
                              () => ref
                                  .read(fundsRepositoryProvider)
                                  .removeFineRule(widget.teamId, r.id),
                            )) {
                              ref.invalidate(fineRulesProvider(widget.teamId));
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _name,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Tên luật, ví dụ Đi muộn'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MoneyInputFormatter(max: 10000000)],
                      decoration: const InputDecoration(hintText: 'Số tiền', suffixText: 'đ'),
                    ),
                  ),
                  LinkButton('Thêm', onTap: _add),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
