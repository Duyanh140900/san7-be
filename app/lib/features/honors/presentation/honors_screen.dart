import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn 7 · Vinh danh & sổ phạt. Làm ở chặng M4.
class HonorsScreen extends StatelessWidget {
  const HonorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: 'Bảng vàng',
      children: [
        ComingSoonCard(
          icon: AppIcons.trophy,
          title: 'Vua phá lưới, MVP, sổ phạt',
          message: 'Bảng vàng tự cập nhật sau mỗi trận, có ở chặng M4.',
        ),
      ],
    );
  }
}
