import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';

/// Dòng "Nhắn tin với đội bạn": lối vào màn 21 từ chi tiết lịch và kết quả trận.
class ChatEntryRow extends StatelessWidget {
  const ChatEntryRow({super.key, required this.teamId, required this.matchId});
  final String teamId;
  final String matchId;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Nhắn tin với đội bạn',
    child: GestureDetector(
      onTap: () => context.push(Routes.chat(teamId, matchId)),
      behavior: HitTestBehavior.opaque,
      child: const AppCard(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text('Nhắn tin với đội bạn', style: TextStyle(fontSize: 16))),
            Text('›', style: TextStyle(fontSize: 20, color: AppColors.disabled)),
          ],
        ),
      ),
    ),
  );
}
