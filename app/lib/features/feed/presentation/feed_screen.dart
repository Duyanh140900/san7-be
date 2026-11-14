import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn 1 · Bảng tin. Nội dung thật làm ở chặng M2.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      title: 'Bảng tin',
      children: [
        ComingSoonCard(
          icon: AppIcons.ball,
          title: 'Kèo quanh bạn',
          message: 'Bảng tin cáp kèo theo khu vực sẽ có ở chặng M2.',
        ),
      ],
    );
  }
}
