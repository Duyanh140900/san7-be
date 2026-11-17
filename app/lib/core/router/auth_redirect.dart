import '../auth/auth_controller.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const welcome = '/welcome';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingTeam = '/onboarding/team';
  static const feed = '/feed';
  static const pitches = '/pitches';
  static const team = '/team';
  static const teamMembers = '/team/members';
  static const teamSchedule = '/team/schedule';
  static const teamFunds = '/team/funds';
  static const teamFundNew = '/team/funds/new';
  static const teamFundsAll = '/team/funds/all';
  static const teamEventNew = '/team/schedule/new';
  static String teamEvent(String id) => '/team/events/$id';
  static const honors = '/honors';
  static const postNew = '/post/new';
  static String post(String id) => '/posts/$id';
  static String postReactions(String id) => '/posts/$id/reactions';
  static String postRequest(String id) => '/posts/$id/request';
  static String postCompare(String teamId, String postId) => '/teams/$teamId/posts/$postId/compare';
  static String request(String teamId, String requestId) => '/teams/$teamId/requests/$requestId';
  static const notifications = '/notifications';
  static const me = '/me';
  static const myPosts = '/me/posts';
  static const bookingHistory = '/me/bookings';
  static const editProfile = '/me/edit';
  static String chat(String teamId, String matchId) => '/teams/$teamId/matches/$matchId/chat';
  static String pitch(String id) => '/pitch/$id';
  static String matchResult(String teamId, String matchId) =>
      '/teams/$teamId/matches/$matchId/result';
  static String teamProfile(String teamId) => '/team-profile/$teamId';
  static String booking(String teamId, String bookingId) => '/teams/$teamId/bookings/$bookingId';
}

/// Quyết định điều hướng theo trạng thái đăng nhập (luồng màn 12).
/// Trả về null nếu được ở lại trang hiện tại.
String? authRedirect(AuthState auth, String location) {
  bool at(String path) => location == path;

  switch (auth) {
    case AuthUnknown():
      return at(Routes.splash) ? null : Routes.splash;
    case AuthSignedOut():
      return at(Routes.welcome) ? null : Routes.welcome;
    case AuthSignedIn() when auth.needsProfile:
      return at(Routes.onboardingProfile) ? null : Routes.onboardingProfile;
    case AuthSignedIn() when auth.needsTeam:
      // Cho phép quay lại sửa hồ sơ ở bước 2
      if (at(Routes.onboardingTeam) || at(Routes.onboardingProfile)) {
        return null;
      }
      return Routes.onboardingTeam;
    case AuthSignedIn():
      // Chưa có đội nhưng đã bấm "Để sau": vẫn được mở lại bước vào đội từ tab Đội
      if (at(Routes.onboardingTeam) && auth.me.teams.isEmpty) return null;
      final inOnboarding =
          at(Routes.splash) || at(Routes.welcome) || location.startsWith('/onboarding');
      return inOnboarding ? Routes.feed : null;
  }
}
