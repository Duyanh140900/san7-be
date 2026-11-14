import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: AppLogo()));
  }
}

/// Logo vuông bo 18, nền xanh, quả bóng trắng (như bản vẽ).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      alignment: Alignment.center,
      child: const AppIcon(AppIcons.ball, size: 36, color: Colors.white, strokeWidth: 1.6),
    );
  }
}
