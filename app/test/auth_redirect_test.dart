import 'package:flutter_test/flutter_test.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/core/auth/auth_controller.dart';
import 'package:san7/core/router/auth_redirect.dart';

MeDto me({bool profile = true, List<MyTeamDto> teams = const []}) => MeDto(
  id: 'u1',
  email: 'a@gmail.com',
  name: 'Anh A',
  position: profile ? Position.forward : null,
  profileCompleted: profile,
  teams: teams,
);

const team = MyTeamDto(
  teamId: 't1',
  name: 'FC Cầu Giấy',
  crestColor: '#0066CC',
  area: 'Cầu Giấy',
  level: TeamLevel.tb,
  role: TeamRole.captain,
  status: MemberStatus.active,
);

void main() {
  group('authRedirect', () {
    test('đang đọc phiên → splash', () {
      expect(authRedirect(const AuthUnknown(), Routes.feed), Routes.splash);
      expect(authRedirect(const AuthUnknown(), Routes.splash), isNull);
    });

    test('chưa đăng nhập → bước 1', () {
      expect(authRedirect(const AuthSignedOut(), Routes.feed), Routes.welcome);
      expect(authRedirect(const AuthSignedOut(), Routes.welcome), isNull);
    });

    test('chưa có hồ sơ → bước 2', () {
      final s = AuthSignedIn(me(profile: false));
      expect(authRedirect(s, Routes.welcome), Routes.onboardingProfile);
      expect(authRedirect(s, Routes.feed), Routes.onboardingProfile);
    });

    test('có hồ sơ, chưa có đội → bước 3, được quay lại bước 2', () {
      final s = AuthSignedIn(me());
      expect(authRedirect(s, Routes.welcome), Routes.onboardingTeam);
      expect(authRedirect(s, Routes.feed), Routes.onboardingTeam);
      expect(authRedirect(s, Routes.onboardingProfile), isNull);
    });

    test('bấm "Để sau" → vào Bảng tin, vẫn mở lại được bước vào đội', () {
      final s = AuthSignedIn(me(), teamStepSkipped: true);
      expect(authRedirect(s, Routes.welcome), Routes.feed);
      expect(authRedirect(s, Routes.team), isNull);
      expect(authRedirect(s, Routes.onboardingTeam), isNull);
    });

    test('đã có đội → không ở lại các bước giới thiệu', () {
      final s = AuthSignedIn(me(teams: [team]));
      expect(authRedirect(s, Routes.onboardingTeam), Routes.feed);
      expect(authRedirect(s, Routes.splash), Routes.feed);
      expect(authRedirect(s, Routes.honors), isNull);
    });
  });
}
