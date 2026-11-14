import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn 2 · Đăng kèo. Làm ở chặng M2.
class PostCreateScreen extends StatelessWidget {
  const PostCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabPage(
        title: 'Đăng kèo',
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Đóng', style: TextStyle(fontSize: 17, color: AppColors.primary)),
          ),
        ],
        children: const [
          ComingSoonCard(
            icon: AppIcons.plus,
            title: 'Đăng kèo tìm đối',
            message: 'Đăng kèo, tuyển người, pass sân và hẹn lịch sẽ có ở chặng M2.',
          ),
        ],
      ),
    );
  }
}
