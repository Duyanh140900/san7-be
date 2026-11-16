import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../funds/data/funds_repository.dart';
import '../../funds/presentation/add_fund_tx_screen.dart';
import '../../matches/matches_providers.dart';
import '../../team/team_providers.dart';

/// "2026-11" của tháng hiện tại (giờ VN) lùi [back] tháng.
String _month(int back) {
  final v = Fmt.vn(DateTime.now());
  final d = DateTime.utc(v.year, v.month - back);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// Màn 7 · Bảng vàng: vinh danh (cầu thủ của tháng, vua phá lưới, danh hiệu đội) và sổ phạt.
class HonorsScreen extends ConsumerStatefulWidget {
  const HonorsScreen({super.key});

  @override
  ConsumerState<HonorsScreen> createState() => _HonorsScreenState();
}

class _HonorsScreenState extends ConsumerState<HonorsScreen> {
  int _tab = 0;
  int _back = 0; // số tháng lùi so với tháng này

  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < 12; i++)
              ListTile(
                title: Text(
                  i == 0
                      ? 'Tháng này'
                      : 'Tháng ${_month(i).split('-')[1].replaceFirst(RegExp('^0'), '')}',
                ),
                subtitle: Text(_month(i)),
                trailing: i == _back ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _back = picked);
  }

  @override
  Widget build(BuildContext context) {
    final month = _month(_back);
    final teamId = ref.watch(currentTeamIdProvider);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(honorsProvider);
          ref.invalidate(finesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text('Bảng vàng', style: Theme.of(context).textTheme.displaySmall),
                  ),
                  GestureDetector(
                    onTap: _pickMonth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Tháng ${int.parse(month.split('-')[1])} ▾',
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Segmented(
              labels: const ['Vinh danh', 'Sổ phạt'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 14),
            if (_tab == 0)
              _Honors(month: month, teamId: teamId)
            else if (teamId == null)
              const AppCard(
                child: Text(
                  'Vào một đội để xem sổ phạt của đội.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              _Fines(teamId: teamId, period: month),
          ],
        ),
      ),
    );
  }
}

class _Honors extends ConsumerWidget {
  const _Honors({required this.month, required this.teamId});
  final String month;
  final String? teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors = ref.watch(honorsProvider((month: month, teamId: teamId)));
    return AsyncView(
      value: honors,
      onRetry: () => ref.invalidate(honorsProvider),
      data: (h) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (h.playerOfMonth != null) ...[
            _PlayerOfMonth(player: h.playerOfMonth!),
            const SizedBox(height: 14),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vua phá lưới',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (h.scorers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Chưa có bàn thắng nào được xác nhận trong tháng này. '
                      'Bảng tự cập nhật sau mỗi trận được hai đội chốt tỉ số.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                for (final (i, p) in h.scorers.indexed)
                  GestureDetector(
                    onTap: () => context.push(Routes.teamProfile(p.team.id)),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 58),
                      decoration: BoxDecoration(
                        border: i == h.scorers.length - 1
                            ? null
                            : const Border(bottom: BorderSide(color: AppColors.divider)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Avatar(name: p.name, url: p.avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  p.team.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${p.goals}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danh hiệu đội',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                if (teamId == null)
                  const Text(
                    'Vào một đội để xem danh hiệu của đội.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  )
                else if (h.teamBadges.isEmpty)
                  const Text(
                    'Chưa có danh hiệu. Bất bại 5 trận liền hoặc fair-play từ 4,5 sao sẽ được ghi nhận.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final b in h.teamBadges)
                        Tag(
                          b.type == TeamBadgeDtoType.unbeaten
                              ? '${b.value.round()} trận bất bại'
                              : 'Đội fair-play (${Fmt.rating(b.value)}★)',
                          bg: AppColors.warnSoft,
                          fg: AppColors.warnText,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerOfMonth extends StatelessWidget {
  const _PlayerOfMonth({required this.player});
  final HonorPlayerDto player;

  @override
  Widget build(BuildContext context) {
    Widget stat(int n, String label) => Expanded(
      child: Column(
        children: [
          Text(
            '$n',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onDarkMuted)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: [
          const Text(
            'CẦU THỦ CỦA THÁNG',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
            child: Avatar(name: player.name, url: player.avatarUrl, size: 78),
          ),
          const SizedBox(height: 10),
          Text(
            player.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [player.team.name, ?Labels.position(player.position)].join(' · '),
            style: const TextStyle(fontSize: 14, color: AppColors.onDarkMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(player.goals, 'Bàn'),
              stat(player.assists, 'Kiến tạo'),
              stat(player.mvps, 'MVP'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fines extends ConsumerWidget {
  const _Fines({required this.teamId, required this.period});
  final String teamId;
  final String period;

  Future<void> _markPaid(BuildContext context, WidgetRef ref, FundTxDto f) async {
    final ok = await runAction(
      context,
      () => ref.read(fundsRepositoryProvider).markFinePaid(teamId, f.id),
      success: 'Đã nộp phạt, cộng vào quỹ',
    );
    if (ok) {
      ref.invalidate(finesProvider);
      ref.invalidate(fundSummaryProvider(teamId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fines = ref.watch(finesProvider((teamId: teamId, period: period)));
    final canManage = ref.watch(teamDetailProvider(teamId)).value?.myRole.canManageFunds ?? false;
    final rules = ref.watch(fineRulesProvider(teamId));
    return AsyncView(
      value: fines,
      onRetry: () => ref.invalidate(finesProvider),
      data: (f) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _Summary('Tổng phạt tháng', Fmt.money(f.total)),
                    _Summary(
                      'Chưa nộp',
                      Fmt.money(f.unpaid),
                      color: f.unpaid > 0 ? AppColors.red : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tiền phạt tự cộng vào quỹ đội khi đánh dấu đã nộp.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sổ phạt',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (canManage)
                      LinkButton(
                        'Ghi phạt',
                        onTap: () => context.push(
                          Routes.teamFundNew,
                          extra: const AddFundTxArgs(type: FundTypeValue.fine),
                        ),
                      ),
                  ],
                ),
                if (f.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Tháng này chưa có khoản phạt nào.',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                for (final (i, t) in f.items.indexed)
                  Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    decoration: BoxDecoration(
                      border: i == f.items.length - 1
                          ? null
                          : const Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        Avatar(name: t.member?.name ?? '?', url: t.member?.avatarUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.member?.name ?? 'Cả đội',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${t.category} · ${Fmt.dayMonth(t.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Fmt.money(t.amount),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: !t.paid && canManage ? () => _markPaid(context, ref, t) : null,
                              child: Tag(
                                t.paid ? 'Đã nộp' : 'Chưa nộp',
                                bg: t.paid ? AppColors.greenSoft : const Color(0xFFFDECEE),
                                fg: t.paid ? AppColors.greenSoftText : AppColors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (canManage && f.items.any((t) => !t.paid))
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Bấm nhãn "Chưa nộp" để đánh dấu đã nộp.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Luật phạt của đội',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (rules.value?.isEmpty ?? false)
                  const Text(
                    'Chưa có luật phạt. Thêm khi ghi phạt.',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                for (final r in rules.value ?? const <FineRuleDto>[])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(r.name, style: const TextStyle(fontSize: 15))),
                        Text(
                          Fmt.money(r.amount),
                          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    ),
  );
}
