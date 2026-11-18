import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';

/// Khung chung của 4 bước onboarding (màn 02, 27, 28, 37): nút quay lại tròn + 3 chấm tiến trình.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.child,
    this.onBack,
    this.onSkip,
  });

  /// 1 đến 4
  final int step;
  final Widget child;
  final VoidCallback? onBack;

  /// Nút "Bỏ qua" góc phải (null thì ẩn)
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (onBack != null) _BackButton(onTap: onBack!) else const SizedBox(width: 40),
                    Expanded(child: _Dots(step: step)),
                    onSkip != null
                        ? LinkButton('Bỏ qua', onTap: onSkip, color: AppColors.textMuted)
                        : const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Quay lại',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const AppIcon(AppIcons.back, color: AppColors.text),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Bước $step trên 4',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 4; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == step ? AppColors.lime : AppColors.lineStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}
