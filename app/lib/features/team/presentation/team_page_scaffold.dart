import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/team_crest.dart';

enum TeamSection {
  overview('Tổng quan', Routes.team),
  members('Thành viên', Routes.teamMembers),
  schedule('Lịch', Routes.teamSchedule),
  funds('Quỹ', Routes.teamFunds);

  const TeamSection(this.label, this.path);
  final String label;
  final String path;
}

/// Khung 4 mục của tab Đội: tiêu đề, thanh mục, nội dung cuộn + kéo để tải lại.
/// [heroHeader] = true (màn 07): [header] nằm trong dải bìa chuyển màu tràn lề, thanh mục nằm trong dải.
class TeamPageScaffold extends StatelessWidget {
  const TeamPageScaffold({
    super.key,
    required this.section,
    required this.header,
    required this.children,
    required this.onRefresh,
    this.heroHeader = false,
  });

  final TeamSection section;
  final Widget header;
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final bool heroHeader;

  @override
  Widget build(BuildContext context) {
    final tabs = TeamSectionTabs(section: section);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (heroHeader)
            _HeroBand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, const SizedBox(height: 16), tabs],
              ),
            )
          else
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [header, const SizedBox(height: 14), tabs],
                ),
              ),
            ),
          for (final c in children)
            Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: c),
        ],
      ),
    );
  }
}

/// Dải bìa xanh đội nhà chuyển sang nền đêm, sọc chéo mờ.
class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123A8F), AppColors.night],
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 14), child: child),
    ),
  );
}

/// Thanh 4 mục (Tổng quan / Thành viên / Lịch / Quỹ): mục chọn nền lime, chữ tối.
class TeamSectionTabs extends StatelessWidget {
  const TeamSectionTabs({super.key, required this.section});
  final TeamSection section;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.button),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        for (final s in TeamSection.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: s == section,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (s != section) context.go(s.path);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s == section ? AppColors.lime : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: s == section ? AppColors.ink : AppColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Tiêu đề mục: phù hiệu nhỏ + tên đội ở trên, tiêu đề display HOA bên dưới (màn 20, 21, 22).
/// [trailing] là tên đội (hoặc số người); [crestColor] có thì hiện phù hiệu.
class TeamTitleHeader extends StatelessWidget {
  const TeamTitleHeader({
    super.key,
    required this.title,
    this.trailing,
    this.crestColor,
    this.crestName,
    this.action,
  });
  final String title;
  final String? trailing;
  final String? crestColor;
  final String? crestName;

  /// Nút bên phải (vd "+ Tạo lịch")
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      if (crestColor != null && trailing != null) ...[
        TeamCrest(name: crestName ?? trailing!, color: crestColor!, width: 36),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trailing != null)
              Text(
                trailing!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            Text(title.toUpperCase(), style: AppText.display(30)),
          ],
        ),
      ),
      ?action,
    ],
  );
}
