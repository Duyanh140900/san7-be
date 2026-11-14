import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/widgets/common.dart';

enum TeamSection {
  overview('Tổng quan', Routes.team),
  members('Thành viên', Routes.teamMembers),
  schedule('Lịch', Routes.teamSchedule),
  funds('Quỹ', Routes.teamFunds);

  const TeamSection(this.label, this.path);
  final String label;
  final String path;
}

/// Khung 4 mục của tab Đội: tiêu đề, segmented control, nội dung cuộn + kéo để tải lại.
class TeamPageScaffold extends StatelessWidget {
  const TeamPageScaffold({
    super.key,
    required this.section,
    required this.header,
    required this.children,
    required this.onRefresh,
  });

  final TeamSection section;
  final Widget header;
  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header,
            const SizedBox(height: 14),
            Segmented(
              labels: [for (final s in TeamSection.values) s.label],
              index: section.index,
              onChanged: (i) {
                if (i != section.index) context.go(TeamSection.values[i].path);
              },
            ),
            for (final c in children) ...[const SizedBox(height: 14), c],
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề lớn bên trái, tên đội nhỏ bên phải (màn 6, 18, 19).
class TeamTitleHeader extends StatelessWidget {
  const TeamTitleHeader({super.key, required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: Theme.of(context).textTheme.displaySmall)),
      if (trailing != null)
        Text(trailing!, style: const TextStyle(fontSize: 15, color: Color(0xFF6E6E73))),
    ],
  );
}
