import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/team_crest.dart';

/// Đầu màn v2: nút chữ bên trái, tiêu đề giữa, [trailing] bên phải (cùng bề rộng để tiêu đề cân giữa).
class ResultTopBar extends StatelessWidget {
  const ResultTopBar({
    super.key,
    required this.title,
    this.leadingLabel,
    this.onLeading,
    this.trailingLabel,
    this.onTrailing,
    this.showBack = false,
  });
  final String title;
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    Widget side(Widget? child, Alignment a) =>
        SizedBox(width: 72, child: Align(alignment: a, child: child));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          side(
            showBack
                ? Semantics(
                    button: true,
                    label: 'Quay lại',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onLeading,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: AppSizes.tapTarget,
                        height: AppSizes.tapTarget,
                        child: Center(child: AppIcon(AppIcons.back, size: 22, color: AppColors.textMain)),
                      ),
                    ),
                  )
                : leadingLabel == null
                ? null
                : _TextAction(leadingLabel!, onLeading, AppColors.textMuted),
            Alignment.centerLeft,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          ),
          side(
            trailingLabel == null ? null : _TextAction(trailingLabel!, onTrailing, AppColors.lime),
            Alignment.centerRight,
          ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction(this.label, this.onTap, this.color);
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget, minWidth: AppSizes.tapTarget),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: TextStyle(fontSize: 15, color: color)),
      ),
    ),
  );
}

/// Thanh nút đáy màn nền tối, viền trên mảnh.
class ResultBottomBar extends StatelessWidget {
  const ResultBottomBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
    decoration: const BoxDecoration(
      color: AppColors.night,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 8), c],
      ],
    ),
  );
}

/// Nhãn đầu nhóm (chữ hoa nhỏ cách chữ) kèm phụ đề tuỳ chọn.
class ResultSection extends StatelessWidget {
  const ResultSection(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: AppText.label),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
        ],
      ],
    ),
  );
}

/// Nút tròn − / + chỉnh tỉ số, vùng bấm 44.
class StepButton extends StatelessWidget {
  const StepButton({super.key, required this.plus, required this.semantic, required this.onTap});
  final bool plus;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: semantic,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          decoration: BoxDecoration(
            color: plus ? AppColors.lime : AppColors.surfaceHigh,
            shape: BoxShape.circle,
            border: plus ? null : Border.all(color: AppColors.lineButton),
          ),
          alignment: Alignment.center,
          child: Text(
            plus ? '+' : '−',
            style: TextStyle(
              fontSize: 24,
              height: 1,
              color: plus ? AppColors.ink : AppColors.textMain,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Một bên tỉ số: phù hiệu, tên, số lớn, nút − / +.
class ScoreSide extends StatelessWidget {
  const ScoreSide({
    super.key,
    required this.name,
    required this.crestColor,
    required this.score,
    this.onMinus,
    this.onPlus,
    this.editable = false,
  });
  final String name;
  final String crestColor;
  final int score;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool editable;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        TeamCrest(name: name, color: crestColor, width: 52),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 8),
        Text('$score', style: AppText.score(60)),
        if (editable) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StepButton(plus: false, semantic: 'Bớt bàn $name', onTap: onMinus),
              const SizedBox(width: 10),
              StepButton(plus: true, semantic: 'Thêm bàn $name', onTap: onPlus),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Khung tỉ số hai đội nền xanh cỏ đậm, có dòng ngày giờ / địa điểm và chip tuỳ chọn.
class ScorePanel extends StatelessWidget {
  const ScorePanel({
    super.key,
    required this.info,
    required this.left,
    required this.right,
    this.badge,
  });
  final String info;
  final ScoreSide left;
  final ScoreSide right;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
    decoration: BoxDecoration(
      color: AppColors.surfaceDeep,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      children: [
        if (badge != null) ...[badge!, const SizedBox(height: 8)],
        Text(
          info,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            left,
            Padding(
              padding: const EdgeInsets.only(top: 86),
              child: Text(':', style: AppText.score(40, color: AppColors.textDim)),
            ),
            right,
          ],
        ),
      ],
    ),
  );
}

/// Chip trạng thái nhỏ (FULL TIME, ĐANG CHỜ...).
class MiniBadge extends StatelessWidget {
  const MiniBadge(this.label, {super.key, this.color = AppColors.lime});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: color),
    ),
  );
}

/// Dải thông báo trên nền tối: [color] quyết định tông (vàng chờ, xanh xong, cam lưu ý).
class NoticeStrip extends StatelessWidget {
  const NoticeStrip({super.key, required this.text, this.color = AppColors.trophy, this.icon});
  final String text;
  final Color color;
  final AppIcons? icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppRadius.group),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[AppIcon(icon!, size: 18, color: color), const SizedBox(width: 10)],
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: color)),
        ),
      ],
    ),
  );
}
