import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../pitches/pitches_providers.dart';
import '../../posts/presentation/post_widgets.dart';
import 'me_screen.dart';

/// Lịch sử đặt sân: các lượt đã qua của đội mình quản lý.
class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(bookingTeamProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const DetailHeader(backLabel: 'Cá nhân', title: 'Lịch sử đặt sân'),
            Expanded(
              child: team == null
                  ? const Center(
                      child: Text(
                        'Chỉ đội trưởng hoặc đội phó mới xem lịch sử đặt sân',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(teamPastBookingsProvider(team.teamId).future),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          AsyncView(
                            value: ref.watch(teamPastBookingsProvider(team.teamId)),
                            onRetry: () => ref.invalidate(teamPastBookingsProvider(team.teamId)),
                            data: (items) => items.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 48),
                                    child: Center(
                                      child: Text(
                                        'Chưa có lượt đặt sân nào',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  )
                                : MeGroup(
                                    children: [
                                      for (final b in items)
                                        MeRow(
                                          title: '${b.pitch.name} · sân ${b.courtNo}',
                                          value: Fmt.slot(b.startAt),
                                          onTap: () => context.push(Routes.booking(b.teamId, b.id)),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
