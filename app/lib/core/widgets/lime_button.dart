import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';
import 'floodlight_animations.dart';

/// Nút chính màu lime (CTA). Đủ trạng thái: mặc định, nhấn, focus, vô hiệu, đang tải.
/// [onPressed] = null → vô hiệu. [loading] → hiện vòng xoay, không bấm được.
class LimeButton extends StatelessWidget {
  const LimeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
    this.height = 54,
    this.shine = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIcons? icon;

  /// Icon sau chữ (vd mũi tên "Nhận kèo →")
  final AppIcons? trailingIcon;
  final bool loading;

  /// true: rộng hết chiều ngang; false: vừa chữ
  final bool expand;
  final double height;
  final bool shine;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    const fg = AppColors.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.4 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: ShineSweep(
              enabled: shine && enabled,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                splashColor: AppColors.ink.withValues(alpha: 0.12),
                highlightColor: AppColors.ink.withValues(alpha: 0.08),
                focusColor: AppColors.ink.withValues(alpha: 0.12),
                hoverColor: Colors.white.withValues(alpha: 0.25),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: height,
                    minWidth: AppSizes.tapTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisSize: expand
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loading) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: fg,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else if (icon != null) ...[
                          AppIcon(icon!, color: fg),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ),
                        if (trailingIcon != null && !loading) ...[
                          const SizedBox(width: 8),
                          AppIcon(trailingIcon!, color: fg, size: 18),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút phụ: nền #15291E, viền trắng mờ (đặt cạnh nút lime).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIcons? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Material(
          color: AppColors.surfaceHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.lineButton),
          ),
          child: InkWell(
            onTap: onPressed,
            splashColor: Colors.white.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: height,
                minWidth: AppSizes.tapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      AppIcon(icon!, color: AppColors.textMain),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
