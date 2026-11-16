import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/attendance/presentation/create_event_screen.dart';
import '../../features/attendance/presentation/schedule_page.dart';
import '../../features/auth/presentation/onboarding_screens.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/funds/presentation/add_fund_tx_screen.dart';
import '../../features/funds/presentation/fund_transactions_screen.dart';
import '../../features/funds/presentation/funds_page.dart';
import '../../features/honors/presentation/honors_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/pitches/presentation/booking_screen.dart';
import '../../features/pitches/presentation/pitch_detail_screen.dart';
import '../../features/pitches/presentation/pitches_screen.dart';
import '../../features/post_create/presentation/post_create_screen.dart';
import '../../features/posts/presentation/compare_requests_screen.dart';
import '../../features/posts/presentation/post_detail_screen.dart';
import '../../features/posts/presentation/request_detail_screen.dart';
import '../../features/posts/presentation/send_request_screen.dart';
import '../../features/team/presentation/members_page.dart';
import '../../features/team/presentation/team_screen.dart';
import '../auth/auth_controller.dart';
import '../widgets/app_shell.dart';
import 'auth_redirect.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeStep()),
      GoRoute(path: Routes.onboardingProfile, builder: (_, _) => const ProfileStep()),
      GoRoute(path: Routes.onboardingTeam, builder: (_, _) => const TeamStep()),
      GoRoute(
        path: Routes.postNew,
        pageBuilder: (_, _) =>
            const MaterialPage(fullscreenDialog: true, child: PostCreateScreen()),
      ),
      // Cáp kèo (M2)
      GoRoute(
        path: '/posts/:postId',
        builder: (_, state) => PostDetailScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: '/posts/:postId/request',
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: SendRequestScreen(postId: state.pathParameters['postId']!),
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/posts/:postId/compare',
        builder: (_, state) => CompareRequestsScreen(
          teamId: state.pathParameters['teamId']!,
          postId: state.pathParameters['postId']!,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/requests/:requestId',
        builder: (_, state) => RequestDetailScreen(
          teamId: state.pathParameters['teamId']!,
          requestId: state.pathParameters['requestId']!,
        ),
      ),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      // Đặt sân (M3)
      GoRoute(
        path: '/pitch/:pitchId',
        builder: (_, state) => PitchDetailScreen(
          pitchId: state.pathParameters['pitchId']!,
          args: state.extra is PitchDetailArgs ? state.extra! as PitchDetailArgs : null,
        ),
      ),
      GoRoute(
        path: '/teams/:teamId/bookings/:bookingId',
        builder: (_, state) => BookingScreen(
          teamId: state.pathParameters['teamId']!,
          bookingId: state.pathParameters['bookingId']!,
        ),
      ),
      // Màn toàn màn hình của tab Đội (đặt trước shell để khớp trước /team/...)
      GoRoute(
        path: Routes.teamFundNew,
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: AddFundTxScreen(
            args: state.extra is AddFundTxArgs
                ? state.extra! as AddFundTxArgs
                : const AddFundTxArgs(),
          ),
        ),
      ),
      GoRoute(path: Routes.teamFundsAll, builder: (_, _) => const FundTransactionsScreen()),
      GoRoute(
        path: Routes.teamEventNew,
        pageBuilder: (_, _) =>
            const MaterialPage(fullscreenDialog: true, child: CreateEventScreen()),
      ),
      GoRoute(
        path: '/team/events/:eventId',
        builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.feed, builder: (_, _) => const FeedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.pitches, builder: (_, _) => const PitchesScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.team,
                pageBuilder: (_, _) => const NoTransitionPage(child: TeamScreen()),
                routes: [
                  GoRoute(
                    path: 'members',
                    pageBuilder: (_, _) => const NoTransitionPage(child: MembersPage()),
                  ),
                  GoRoute(
                    path: 'schedule',
                    pageBuilder: (_, _) => const NoTransitionPage(child: SchedulePage()),
                  ),
                  GoRoute(
                    path: 'funds',
                    pageBuilder: (_, _) => const NoTransitionPage(child: FundsPage()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.honors, builder: (_, _) => const HonorsScreen())],
          ),
        ],
      ),
    ],
  );
});
