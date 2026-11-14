import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import '../../features/auth/data/auth_repository.dart';
import '../api/api_client.dart';
import '../api/api_error.dart';

sealed class AuthState {
  const AuthState();
}

/// Đang đọc phiên đã lưu khi mở app. [offline]: có phiên nhưng chưa gọi được máy chủ.
class AuthUnknown extends AuthState {
  const AuthUnknown({this.offline = false});
  final bool offline;
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.me, {this.teamStepSkipped = false});
  final MeDto me;
  final bool teamStepSkipped;

  bool get needsProfile => !me.profileCompleted;
  bool get needsTeam => me.teams.isEmpty && !teamStepSkipped;
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    ref.listen(sessionExpiredProvider, (_, _) => state = const AuthSignedOut());
    Future.microtask(_restore);
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    if (!await _repo.hasSession()) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final me = await _repo.getMe();
      state = AuthSignedIn(me, teamStepSkipped: await _repo.teamStepSkipped());
    } on ApiError catch (e) {
      if (e.statusCode == 401 || !await _repo.hasSession()) {
        // Phiên hết hạn hẳn (interceptor đã xoá token)
        state = const AuthSignedOut();
        return;
      }
      // Mất mạng hoặc máy chủ lỗi: giữ phiên, thử lại sau ít giây
      state = const AuthUnknown(offline: true);
      await Future<void>.delayed(_retryDelay);
      if (state is AuthUnknown) await _restore();
    }
  }

  static const _retryDelay = Duration(seconds: 3);

  Future<void> signInWithGoogle() async {
    final me = await _repo.signInWithGoogle();
    state = AuthSignedIn(me, teamStepSkipped: await _repo.teamStepSkipped());
  }

  Future<void> updateProfile({
    required String name,
    required PositionValue position,
    int? shirtNumber,
    String? area,
  }) async {
    final me = await _repo.updateProfile(
      name: name,
      position: position,
      shirtNumber: shirtNumber,
      area: area,
    );
    _setMe(me);
  }

  /// Gọi lại /me sau khi tạo/vào đội.
  Future<void> reloadMe() async => _setMe(await _repo.getMe());

  Future<void> skipTeamStep() async {
    await _repo.skipTeamStep();
    final s = state;
    if (s is AuthSignedIn) state = AuthSignedIn(s.me, teamStepSkipped: true);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthSignedOut();
  }

  void _setMe(MeDto me) {
    final s = state;
    state = AuthSignedIn(me, teamStepSkipped: s is AuthSignedIn && s.teamStepSkipped);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
