import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Trang trong tab: tiêu đề lớn kiểu Apple + nội dung cuộn.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.title, required this.children, this.actions});

  final String title;
  final List<Widget> children;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.displaySmall)),
                ...?actions,
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Thẻ trắng bo 18 báo tính năng sẽ có ở chặng sau.
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, required this.icon, required this.title, required this.message});

  final AppIcons icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, color: AppColors.primarySoftText),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
