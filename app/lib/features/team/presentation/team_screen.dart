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
import '../../../core/widgets/team_crest.dart';
import '../../../core/widgets/tab_page.dart';
import '../../attendance/presentation/event_widgets.dart';
import '../team_providers.dart';
import 'team_page_scaffold.dart';
import 'team_settings_sheet.dart';
import 'widgets/role_tag.dart';

/// Tab Đội · Tổng quan (màn 5). Chưa có đội active → hướng dẫn tạo/vào đội.
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
      onRefresh: () async {
        ref.invalidate(teamDetailProvider(teamId));
        ref.invalidate(upcomingEventsProvider(teamId));
        ref.invalidate(membersProvider(teamId));
        await ref.read(teamDetailProvider(teamId).future);
      },
      header: AsyncView(
        value: team,
        onRetry: () => ref.invalidate(teamDetailProvider(teamId)),
        data: (t) => _TeamHeader(team: t),
      ),
      children: [
        _StatsCard(year: Fmt.vn(DateTime.now()).year),
        AsyncView(
          value: events,
          onRetry: () => ref.invalidate(upcomingEventsProvider(teamId)),
          data: (list) => list.isEmpty
              ? _NoEventCard(canCreate: team.value?.myRole.canManageEvents ?? false)
              : _NextEventDarkCard(teamId: teamId, event: list.first),
        ),
        AsyncView(
          value: members,
          onRetry: () => ref.invalidate(membersProvider(teamId)),
          data: (m) => _MembersPreview(members: m),
        ),
      ],
    );
  }
}

/// Huy hiệu hình khiên + tên đội + "Sân 7 · Từ 2026 · 18 thành viên" + nút cài đặt.
class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});
  final TeamDetailDto team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TeamCrest(name: team.name, color: team.crestColor),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Sân 7 · Từ ${Fmt.vn(team.createdAt).year} · ${team.memberCount} thành viên',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.more, size: 22, color: AppColors.text),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thành tích mùa: số liệu thật có từ chặng M4 (kết quả trận).
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    Widget stat(String n, String label, [Color? color]) => Expanded(
      child: Column(
        children: [
          Text(
            n,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader('Thành tích mùa $year'),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('0', 'Trận'),
              stat('0', 'Thắng', const Color(0xFF1F7A35)),
              stat('0', 'Hoà'),
              stat('0', 'Thua', AppColors.red),
            ],
          ),
          const Divider(height: 28, color: Color(0xFFF0F0F0)),
          const Text(
            'Chưa có trận nào. Kết quả sẽ tự cập nhật sau mỗi trận.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Thẻ tối "Trận tới" với tiến độ điểm danh và nút tham gia / vắng.
class _NextEventDarkCard extends ConsumerWidget {
  const _NextEventDarkCard({required this.teamId, required this.event});
  final String teamId;
  final EventSummaryDto event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = event.counts;
    final total = c.go + c.maybe + c.no + c.pending;
    final answered = c.go + c.maybe + c.no;
    final mine = statusValue(event.myStatus);
    const muted = Color(0xFFCCCCCC);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(switch (event.kind) {
                  EventKindKnown(value: EventKindValue.match) => 'Trận tới',
                  _ => 'Lịch tới',
                }, style: const TextStyle(fontSize: 13, color: muted)),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.teamEvent(event.id)),
                child: Text(
                  '${Fmt.weekday(event.startAt)} ${Fmt.dayMonth(event.startAt)} · ${Fmt.time(event.startAt)} · Chi tiết',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF2997FF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            event.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          if (event.location != null) ...[
            const SizedBox(height: 6),
            Text(event.location!, style: const TextStyle(fontSize: 13, color: muted)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Điểm danh', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
              Text(
                '${c.go} / $total đã xác nhận đi',
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : c.go / total,
              minHeight: 6,
              backgroundColor: const Color(0xFF3A3A3C),
              color: const Color(0xFF2997FF),
            ),
          ),
          if (answered < total) ...[
            const SizedBox(height: 6),
            Text(
              '${total - answered} người chưa trả lời',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _DarkButton(
                  label: mine == AttendanceStatusValue.go ? 'Đã tham gia' : 'Tôi tham gia',
                  filled: true,
                  onTap: () =>
                      setMyAttendance(context, ref, teamId, event.id, AttendanceStatusValue.go),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DarkButton(
                  label: mine == AttendanceStatusValue.no ? 'Đã báo vắng' : 'Vắng',
                  filled: false,
                  onTap: () =>
                      setMyAttendance(context, ref, teamId, event.id, AttendanceStatusValue.no),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: filled ? null : Border.all(color: const Color(0xFF555555)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: filled ? AppColors.text : Colors.white,
        ),
      ),
    ),
  );
}

class _NoEventCard extends StatelessWidget {
  const _NoEventCard({required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CardHeader('Chưa có lịch sắp tới'),
        const SizedBox(height: 4),
        Text(
          canCreate
              ? 'Tạo lịch trận hoặc đá nội bộ để anh em điểm danh.'
              : 'Đội trưởng hoặc phó đội sẽ tạo lịch để anh em điểm danh.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        if (canCreate) LinkButton('Tạo lịch', onTap: () => context.push(Routes.teamEventNew)),
      ],
    ),
  );
}

class _MembersPreview extends StatelessWidget {
  const _MembersPreview({required this.members});
  final MemberListDto members;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          CardHeader(
            'Thành viên',
            trailing: LinkButton('Xem tất cả', onTap: () => context.go(Routes.teamMembers)),
          ),
          for (final (i, m) in members.active.take(3).indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
            MemberRow(member: m),
          ],
          if (members.pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinkButton(
                '${members.pending.length} yêu cầu chờ duyệt',
                onTap: () => context.go(Routes.teamMembers),
              ),
            ),
        ],
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
          const Tag('Chờ duyệt', bg: Color(0x24FF9500), fg: Color(0xFFB25E00)),
        ],
      ),
    );
  }
}
