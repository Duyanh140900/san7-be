import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../core/widgets/team_crest.dart';
import '../../attendance/presentation/event_widgets.dart';
import '../../matches/matches_providers.dart';
import '../team_providers.dart';
import 'team_page_scaffold.dart';
import 'team_settings_sheet.dart';
import 'widgets/role_tag.dart';

/// Tab Đội · Tổng quan (màn 07). Chưa có đội active → hướng dẫn tạo/vào đội.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const _NoTeamView();
    return _OverviewPage(teamId: teamId);
  }
}

class _OverviewPage extends ConsumerWidget {
  const _OverviewPage({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamDetailProvider(teamId));
    final events = ref.watch(upcomingEventsProvider(teamId));
    final members = ref.watch(membersProvider(teamId));

    return TeamPageScaffold(
      section: TeamSection.overview,
      heroHeader: true,
      onRefresh: () async {
        ref.invalidate(teamDetailProvider(teamId));
        ref.invalidate(upcomingEventsProvider(teamId));
        ref.invalidate(membersProvider(teamId));
        ref.invalidate(teamProfileProvider(teamId));
        ref.invalidate(fundSummaryProvider(teamId));
        await ref.read(teamDetailProvider(teamId).future);
      },
      header: AsyncView(
        value: team,
        onRetry: () => ref.invalidate(teamDetailProvider(teamId)),
        data: (t) => _TeamHeader(team: t),
      ),
      children: [
        _StatsCard(teamId: teamId),
        AsyncView(
          value: events,
          onRetry: () => ref.invalidate(upcomingEventsProvider(teamId)),
          data: (list) => list.isEmpty
              ? _NoEventCard(canCreate: team.value?.myRole.canManageEvents ?? false)
              : _NextEventCard(teamId: teamId, event: list.first, team: team.value),
        ),
        AsyncView(
          value: members,
          onRetry: () => ref.invalidate(membersProvider(teamId)),
          data: (m) => _LineupCard(members: m),
        ),
        _FundCard(teamId: teamId),
      ],
    );
  }
}

/// Phù hiệu khiên + tên đội (display HOA) + "Sân 7 · Từ 2026 · 18 thành viên" + chip vai trò + nút cài đặt.
class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});
  final TeamDetailDto team;

  @override
  Widget build(BuildContext context) {
    final role = switch (team.myRole) {
      TeamRoleKnown(:final value) => value,
      _ => TeamRoleValue.member,
    };
    final roleText = switch (role) {
      TeamRoleValue.captain => 'BẠN LÀ ĐỘI TRƯỞNG',
      TeamRoleValue.vice => 'BẠN LÀ PHÓ ĐỘI',
      TeamRoleValue.treasurer => 'BẠN LÀ THỦ QUỸ',
      TeamRoleValue.member => 'THÀNH VIÊN',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TeamCrest(name: team.name, color: team.crestColor, width: 76, glow: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(34),
              ),
              const SizedBox(height: 6),
              Text(
                'Sân 7 · Từ ${Fmt.vn(team.createdAt).year} · ${team.memberCount} thành viên',
                style: const TextStyle(fontSize: 13, color: AppColors.textBody),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  roleText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Cài đặt đội',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => showTeamSettings(context, team),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: AppSizes.tapTarget,
              height: AppSizes.tapTarget,
              decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.more, size: 22, color: AppColors.textMain),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thẻ nền tối bo 24 viền mảnh (dùng chung các khối màn 07).
class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

Widget _panelLabel(String text, {Color color = AppColors.textDim}) => Text(
  text.toUpperCase(),
  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: color),
);

/// Thành tích mùa: vòng tỉ lệ thắng, thanh thắng/hoà/thua, 5 trận gần nhất.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(teamProfileProvider(teamId)).value;
    final r = profile?.record;
    final played = r?.played ?? 0;
    final rate = played == 0 ? 0.0 : (r!.wins / played);
    final maxN = [r?.wins ?? 0, r?.draws ?? 0, r?.losses ?? 0].fold<int>(1, math.max);

    Widget bar(String label, int n, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: n == 0 ? 0.04 : n / maxN,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text('$n', textAlign: TextAlign.right, style: AppText.display(18)),
          ),
        ],
      ),
    );

    final form = r?.form ?? const <TeamRecordDtoFormItem>[];
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(child: CustomPaint(painter: _RingPainter(rate))),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(rate * 100).round()}%', style: AppText.display(30)),
                        const Text(
                          'Tỉ lệ thắng',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _panelLabel('Mùa ${DateTime.now().year} · $played trận'),
                    const SizedBox(height: 10),
                    bar('Thắng', r?.wins ?? 0, AppColors.lime),
                    bar('Hoà', r?.draws ?? 0, AppColors.trophy),
                    bar('Thua', r?.losses ?? 0, AppColors.card),
                  ],
                ),
              ),
            ],
          ),
          if (form.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final (i, f) in form.take(5).toList().indexed)
                  _FormBadge(item: f, latest: i == 0),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  played == 0
                      ? 'Chưa có trận nào. Kết quả tự cập nhật sau mỗi trận được hai đội xác nhận.'
                      : 'Bàn thắng ${r!.goalsFor} · bàn thua ${r.goalsAgainst}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
              LinkButton('Hồ sơ đội', onTap: () => context.push(Routes.teamProfile(teamId))),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = AppColors.surfaceHigh;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = AppColors.lime;
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

/// Ô T / H / B (thắng, hoà, thua); trận mới nhất có viền nhấn.
class _FormBadge extends StatelessWidget {
  const _FormBadge({required this.item, required this.latest});
  final TeamRecordDtoFormItem item;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final v = switch (item) {
      TeamRecordDtoFormItemKnown(:final value) => value,
      _ => null,
    };
    final (text, color) = switch (v) {
      TeamRecordDtoFormItemValue.w => ('T', AppColors.lime),
      TeamRecordDtoFormItemValue.d => ('H', AppColors.trophy),
      TeamRecordDtoFormItemValue.l => ('B', AppColors.card),
      null => ('?', AppColors.textDim),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: latest ? Border.all(color: AppColors.textMain, width: 2) : null,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
    );
  }
}

/// "vs FC Mỹ Đình" trong tiêu đề lịch → tên đội đối thủ (nếu có).
String? _opponentName(String title) {
  final m = RegExp(r'\bvs\.?\s+(.+)$', caseSensitive: false).firstMatch(title);
  return m?.group(1)?.trim();
}

/// Thẻ "Trận tới · còn N ngày": hai phù hiệu, VS, địa điểm, tiến độ điểm danh, nút tham gia / vắng.
class _NextEventCard extends ConsumerWidget {
  const _NextEventCard({required this.teamId, required this.event, required this.team});
  final String teamId;
  final EventSummaryDto event;
  final TeamDetailDto? team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = event.counts;
    final total = c.go + c.maybe + c.no + c.pending;
    final mine = statusValue(event.myStatus);
    final isMatch = event.kind is EventKindKnown &&
        (event.kind as EventKindKnown).value == EventKindValue.match;
    final opponent = isMatch ? _opponentName(event.title) : null;

    Widget crest(String name, String color) => Column(
      children: [
        TeamCrest(name: name, color: color, width: 48),
        const SizedBox(height: 6),
        SizedBox(
          width: 88,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    void go(AttendanceStatusValue s) => setMyAttendance(context, ref, teamId, event.id, s);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelLabel(
                  '${isMatch ? 'Trận tới' : 'Lịch tới'} · ${Fmt.countdown(event.startAt)}',
                  color: AppColors.lime,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.teamEvent(event.id)),
                behavior: HitTestBehavior.opaque,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${Fmt.weekday(event.startAt)} ${Fmt.dayMonth(event.startAt)} · ${Fmt.time(event.startAt)}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (opponent != null && team != null)
            Row(
              children: [
                crest(team!.name, team!.crestColor),
                Expanded(
                  child: Column(
                    children: [
                      Text('VS', style: AppText.display(26, color: AppColors.lime)),
                      if (event.location != null)
                        Text(
                          event.location!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                crest(opponent, '#E53935'),
              ],
            )
          else ...[
            const SizedBox(height: 4),
            Text(event.title.toUpperCase(), style: AppText.display(26)),
            if (event.location != null) ...[
              const SizedBox(height: 4),
              Text(event.location!, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Điểm danh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(
                '${c.go} / $total đi',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : c.go / total,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: mine == AttendanceStatusValue.go
                    ? GhostButton(
                        label: 'Đã tham gia',
                        icon: AppIcons.checkCircle,
                        height: 48,
                        onPressed: () => go(AttendanceStatusValue.go),
                      )
                    : LimeButton(
                        label: 'Tôi tham gia',
                        height: 48,
                        onPressed: () => go(AttendanceStatusValue.go),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(
                  label: mine == AttendanceStatusValue.no ? 'Đã báo vắng' : 'Vắng',
                  height: 48,
                  onPressed: () => go(AttendanceStatusValue.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoEventCard extends StatelessWidget {
  const _NoEventCard({required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelLabel('Chưa có lịch sắp tới'),
        const SizedBox(height: 6),
        Text(
          canCreate
              ? 'Tạo lịch trận hoặc đá nội bộ để anh em điểm danh.'
              : 'Đội trưởng hoặc phó đội sẽ tạo lịch để anh em điểm danh.',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        if (canCreate) LinkButton('Tạo lịch', onTap: () => context.push(Routes.teamEventNew)),
      ],
    ),
  );
}

/// Đội hình: thành viên thật theo số áo; "Xem tất cả" sang tab Thành viên.
class _LineupCard extends StatelessWidget {
  const _LineupCard({required this.members});
  final MemberListDto members;

  String _short(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.length < 2) return name;
    return '${String.fromCharCode(p.first.runes.first)}.${p.last}';
  }

  @override
  Widget build(BuildContext context) {
    final list = members.active.take(6).toList();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ĐỘI HÌNH', style: AppText.display(20))),
              LinkButton('Xem tất cả', onTap: () => context.go(Routes.teamMembers)),
            ],
          ),
          if (list.isEmpty)
            const Text(
              'Chưa có thành viên.',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in list)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          m.shirtNumber?.toString() ?? '–',
                          style: AppText.display(20, color: AppColors.lime),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _short(m.name),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          if (members.pending.isNotEmpty)
            LinkButton(
              '${members.pending.length} yêu cầu chờ duyệt',
              onTap: () => context.go(Routes.teamMembers),
            ),
        ],
      ),
    );
  }
}

/// Quỹ đội: số dư và số người chưa đóng (dữ liệu thật từ quỹ).
class _FundCard extends ConsumerWidget {
  const _FundCard({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(fundSummaryProvider(teamId)).value;
    if (s == null) return const SizedBox.shrink();
    final unpaid = s.dues?.unpaid.length ?? 0;
    return GestureDetector(
      onTap: () => context.go(Routes.teamFunds),
      behavior: HitTestBehavior.opaque,
      child: _Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _panelLabel('Quỹ đội'),
                  const SizedBox(height: 4),
                  Text(Fmt.money(s.balance), style: AppText.display(30, color: AppColors.lime)),
                  if (unpaid > 0)
                    Text(
                      '$unpaid người chưa đóng',
                      style: const TextStyle(fontSize: 13, color: AppColors.hotText),
                    ),
                ],
              ),
            ),
            const AppIcon(AppIcons.chevronRight, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// Dòng thành viên: avatar, tên, vị trí · số áo, nhãn vai trò.
class MemberRow extends StatelessWidget {
  const MemberRow({super.key, required this.member, this.isMe = false, this.trailing});
  final MemberDto member;
  final bool isMe;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final line = Labels.playerLine(member.position, member.shirtNumber);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Avatar(name: member.name, url: member.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${member.name} (bạn)' : member.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (line.isNotEmpty)
                  Text(line, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          trailing ?? RoleTag(member.role),
        ],
      ),
    );
  }
}

/// Chưa có đội active: thẻ đội đang chờ duyệt hoặc hướng dẫn tạo / vào đội.
class _NoTeamView extends ConsumerWidget {
  const _NoTeamView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final teams = auth is AuthSignedIn ? auth.me.teams : const <MyTeamDto>[];
    return TabPage(
      title: 'Đội',
      actions: [
        TextButton(
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Đăng xuất'),
        ),
      ],
      children: [
        for (final t in teams) ...[_PendingTeamCard(team: t), const SizedBox(height: 12)],
        if (teams.isEmpty)
          const ComingSoonCard(
            icon: AppIcons.team,
            title: 'Bạn chưa có đội',
            message: 'Tạo đội mới hoặc nhập mã mời đội trưởng gửi.',
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.push(Routes.onboardingTeam),
          child: Text(teams.isEmpty ? 'Tạo hoặc tham gia đội' : 'Tạo hoặc tham gia đội khác'),
        ),
        LinkButton(
          'Kiểm tra lại trạng thái duyệt',
          onTap: () => ref.read(authControllerProvider.notifier).reloadMe(),
        ),
      ],
    );
  }
}

class _PendingTeamCard extends StatelessWidget {
  const _PendingTeamCard({required this.team});
  final MyTeamDto team;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          TeamCrest(name: team.name, color: team.crestColor, width: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(team.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${team.area} · ${Labels.level(team.level)}',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Tag('Chờ duyệt', bg: AppColors.warnSoft, fg: AppColors.warnText),
        ],
      ),
    );
  }
}
