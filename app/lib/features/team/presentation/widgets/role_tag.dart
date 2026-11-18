import 'package:material_ui/material_ui.dart';

import '../../../../api/exports.dart';
import '../../../../core/labels.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/common.dart';

/// Màu nhãn vai trò theo bản vẽ (màn 5, 19).
(Color, Color) roleColors(TeamRoleValue v) => switch (v) {
  TeamRoleValue.captain => (AppColors.lime, AppColors.ink),
  TeamRoleValue.vice => (const Color(0x292F7BFF), AppColors.homeText),
  TeamRoleValue.treasurer => (AppColors.orangeSoft, AppColors.orangeText),
  TeamRoleValue.member => (AppColors.surfaceHigh, AppColors.textMuted),
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
