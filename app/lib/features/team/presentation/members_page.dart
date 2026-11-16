import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/labels.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../data/team_repository.dart';
import '../team_providers.dart';
import 'team_page_scaffold.dart';
import 'team_screen.dart' show MemberRow;

/// Tab Đội · Thành viên & mời (màn 19).
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key});

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  String _query = '';
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final teamId = ref.watch(currentTeamIdProvider);
    if (teamId == null) return const SizedBox.shrink();
    final team = ref.watch(teamDetailProvider(teamId));
    final members = ref.watch(membersProvider(teamId));
    final auth = ref.watch(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;
    final role = team.value?.myRole;

    return TeamPageScaffold(
      section: TeamSection.members,
      onRefresh: () async {
        ref.invalidate(teamDetailProvider(teamId));
        ref.invalidate(membersProvider(teamId));
        await ref.read(membersProvider(teamId).future);
      },
      header: TeamTitleHeader(
        title: 'Thành viên',
        trailing: team.value != null ? '${team.value!.memberCount} người' : null,
      ),
      children: [
        if (team.value?.inviteCode != null) _InviteCard(teamId: teamId, team: team.value!),
        AsyncView(
          value: members,
          onRetry: () => ref.invalidate(membersProvider(teamId)),
          data: (m) => Column(
            children: [
              if (m.pending.isNotEmpty) ...[
                _PendingCard(teamId: teamId, pending: m.pending),
                const SizedBox(height: 14),
              ],
              _SearchField(onChanged: (q) => setState(() => _query = q.trim().toLowerCase())),
              const SizedBox(height: 14),
              _MemberList(
                teamId: teamId,
                members: m.active.where((x) => x.name.toLowerCase().contains(_query)).toList(),
                myId: myId,
                canEditRoles: role?.isCaptain ?? false,
                expanded: _expanded,
                onToggle: (id) => setState(() => _expanded = _expanded == id ? null : id),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.teamId, required this.team});
  final String teamId;
  final TeamDetailDto team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = team.inviteCode!;
    final expires = team.inviteExpiresAt;
    final days = expires == null ? null : expires.difference(DateTime.now()).inDays + 1;
    final expiryText = switch (days) {
      null => 'Không hết hạn',
      <= 0 => 'Đã hết hạn',
      _ => 'Hết hạn sau $days ngày',
    };
    final shareText = 'Vào đội ${team.name} trên app Sân 7: mở app → Tham gia đội → nhập mã $code';

    Future<void> regenerate() async {
      final ok = await runAction(
        context,
        () => ref.read(teamRepositoryProvider).regenerateInvite(teamId),
        success: 'Đã tạo mã mời mới, mã cũ hết hiệu lực',
      );
      if (ok) ref.invalidate(teamDetailProvider(teamId));
    }

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mã mời vào đội',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showToast(context, 'Đã chép mã $code', type: ToastType.success);
                  },
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$expiryText · ',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: regenerate,
                      child: const Text(
                        'Tạo mã mới',
                        style: TextStyle(fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            children: [
              _SmallButton(
                label: 'Chia sẻ',
                filled: true,
                onTap: () => SharePlus.instance.share(ShareParams(text: shareText)),
              ),
              const SizedBox(height: 8),
              _SmallButton(
                label: 'Mã QR',
                filled: false,
                onTap: () => _showQr(context, team.name, code),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQr(BuildContext context, String teamName, String code) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(teamName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              QrImageView(data: 'san7:invite:$code', size: 220),
              const SizedBox(height: 12),
              Text(
                code,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              const Text(
                'Quét bằng app Sân 7 để vào đội',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 36, minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.primary : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: filled ? Colors.white : AppColors.primary,
        ),
      ),
    ),
  );
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.teamId, required this.pending});
  final String teamId;
  final List<MemberDto> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(teamRepositoryProvider);
    Future<void> act(Future<void> Function() f, String done) async {
      if (await runAction(context, f, success: done)) {
        ref.invalidate(membersProvider(teamId));
        ref.invalidate(teamDetailProvider(teamId));
      }
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardHeader('Chờ duyệt · ${pending.length}'),
          for (final (i, m) in pending.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
            MemberRow(
              member: m,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SmallButton(
                    label: 'Duyệt',
                    filled: true,
                    onTap: () => act(() => repo.approve(teamId, m.userId), 'Đã duyệt ${m.name}'),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => act(() => repo.reject(teamId, m.userId), 'Đã từ chối ${m.name}'),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Text(
                        'Từ chối',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        const AppIcon(AppIcons.search, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(hintText: 'Tìm thành viên'),
          ),
        ),
      ],
    ),
  );
}

class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.teamId,
    required this.members,
    required this.myId,
    required this.canEditRoles,
    required this.expanded,
    required this.onToggle,
  });

  final String teamId;
  final List<MemberDto> members;
  final String? myId;
  final bool canEditRoles;
  final String? expanded;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) {
      return const AppCard(
        child: Text('Không tìm thấy thành viên', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (i, m) in members.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF0F0F0)),
            InkWell(
              onTap: canEditRoles && m.userId != myId ? () => onToggle(m.userId) : null,
              child: MemberRow(member: m, isMe: m.userId == myId),
            ),
            if (expanded == m.userId) _RoleEditor(teamId: teamId, member: m),
          ],
        ],
      ),
    );
  }
}

/// Phân quyền cho một thành viên (chỉ đội trưởng).
class _RoleEditor extends ConsumerWidget {
  const _RoleEditor({required this.teamId, required this.member});
  final String teamId;
  final MemberDto member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = switch (member.role) {
      TeamRoleKnown(:final value) => value,
      _ => TeamRoleValue.member,
    };
    final repo = ref.read(teamRepositoryProvider);

    Future<void> pick(TeamRoleValue v) async {
      if (v == current) return;
      if (v == TeamRoleValue.captain) {
        final ok = await _confirm(
          context,
          'Trao quyền đội trưởng?',
          '${member.name} sẽ thành đội trưởng, bạn chuyển thành phó đội.',
          'Trao quyền',
        );
        if (!ok || !context.mounted) return;
      }
      if (await runAction(
        context,
        () => repo.changeRole(teamId, member.userId, v),
        success: '${member.name}: ${Labels.roleOf(v)}',
      )) {
        ref.invalidate(membersProvider(teamId));
        ref.invalidate(teamDetailProvider(teamId));
        if (v == TeamRoleValue.captain) await ref.read(authControllerProvider.notifier).reloadMe();
      }
    }

    Future<void> removeMember() async {
      final ok = await _confirm(
        context,
        'Mời ${member.name} ra khỏi đội?',
        'Người này sẽ không xem được lịch, quỹ của đội nữa.',
        'Mời ra',
      );
      if (!ok || !context.mounted) return;
      if (await runAction(
        context,
        () => repo.remove(teamId, member.userId),
        success: 'Đã mời ${member.name} ra khỏi đội',
      )) {
        ref.invalidate(membersProvider(teamId));
        ref.invalidate(teamDetailProvider(teamId));
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 14),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phân quyền cho ${member.name}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in Labels.rolePicker)
                _RolePill(label: Labels.roleOf(v), selected: v == current, onTap: () => pick(v)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Thủ quỹ: thêm thu chi, nhắc đóng quỹ. Phó đội: tạo lịch, duyệt thành viên.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          LinkButton('Mời ra khỏi đội', color: AppColors.red, onTap: removeMember),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
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

Future<bool> _confirm(BuildContext context, String title, String body, String action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}
