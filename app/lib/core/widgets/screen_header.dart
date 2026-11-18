import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Nút vuông bo 16 viền mảnh (quay lại, gọi, cờ...) của bản vẽ v2. Vùng bấm 44x44.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.tooltip,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Đầu màn v2: nút quay lại vuông + tiêu đề Barlow HOA + phần bên phải.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing, this.titleSuffix});
  final String title;
  final Widget? trailing;
  final Widget? titleSuffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        SquareIconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          child: const AppIcon(AppIcons.back, size: 22, color: AppColors.textMain),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(28),
          ),
        ),
        if (titleSuffix != null) ...[const SizedBox(width: 8), titleSuffix!],
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}
