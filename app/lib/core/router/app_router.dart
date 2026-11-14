import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/onboarding_screens.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/honors/presentation/honors_screen.dart';
import '../../features/pitches/presentation/pitches_screen.dart';
import '../../features/post_create/presentation/post_create_screen.dart';
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
            routes: [GoRoute(path: Routes.team, builder: (_, _) => const TeamScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.honors, builder: (_, _) => const HonorsScreen())],
          ),
        ],
      ),
    ],
  );
});
