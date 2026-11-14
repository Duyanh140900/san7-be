import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn 3 · Bản đồ đặt sân. Làm ở chặng M3.
class PitchesScreen extends StatelessWidget {
  const PitchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: 'Đặt sân',
      children: [
        ComingSoonCard(
          icon: AppIcons.pin,
          title: 'Sân gần bạn',
          message: 'Bản đồ sân, khung giờ trống và giữ chỗ sẽ có ở chặng M3.',
        ),
      ],
    );
  }
}
