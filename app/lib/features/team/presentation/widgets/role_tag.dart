import 'package:material_ui/material_ui.dart';

import '../../../../api/exports.dart';
import '../../../../core/labels.dart';
import '../../../../core/widgets/common.dart';

/// Màu nhãn vai trò theo bản vẽ (màn 5, 19).
(Color, Color) roleColors(TeamRoleValue v) => switch (v) {
  TeamRoleValue.captain => (const Color(0xFFE8F0FB), const Color(0xFF0058B0)),
  TeamRoleValue.vice => (const Color(0xFFF5F5F7), const Color(0xFF1D1D1F)),
  TeamRoleValue.treasurer => (const Color(0xFFFDF0E6), const Color(0xFFA04800)),
  TeamRoleValue.member => (const Color(0xFFF5F5F7), const Color(0xFF6E6E73)),
};

/// Nhãn vai trò; thành viên thường thì không hiện (như bản vẽ), trừ khi [showMember].
class RoleTag extends StatelessWidget {
  const RoleTag(this.role, {super.key, this.showMember = false});
  final TeamRole role;
  final bool showMember;

  @override
  Widget build(BuildContext context) {
    final v = switch (role) {
      TeamRoleKnown(:final value) => value,
      _ => TeamRoleValue.member,
    };
    if (v == TeamRoleValue.member && !showMember) return const SizedBox.shrink();
    final (bg, fg) = roleColors(v);
    return Tag(Labels.roleOf(v), bg: bg, fg: fg);
  }
}
