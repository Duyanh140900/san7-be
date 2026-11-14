import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';

/// Khung chung của 3 bước màn 12: nút quay lại tròn + 3 chấm tiến trình.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({super.key, required this.step, required this.child, this.onBack});

  /// 1, 2 hoặc 3
  final int step;
  final Widget child;
  final VoidCallback? onBack;

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
                    const SizedBox(width: 40),
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
          decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
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
      label: 'Bước $step trên 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= 3; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == step ? AppColors.primary : AppColors.pillBorder,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}
