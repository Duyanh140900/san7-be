import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/config.dart';

/// Người dùng bấm huỷ hộp chọn tài khoản Google.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

class AuthRepository {
  AuthRepository(this._api, this._storage, [GoogleSignIn? google])
    : _google = google ?? GoogleSignIn.instance;

  final San7Api _api;
  final TokenStorage _storage;
  final GoogleSignIn _google;
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= _google.initialize(
    serverClientId: AppConfig.googleWebClientId.isEmpty ? null : AppConfig.googleWebClientId,
  );

  Future<bool> hasSession() async => await _storage.readRefresh() != null;

  /// Đăng nhập Google → gửi ID token cho backend → lưu cặp token.
  Future<MeDto> signInWithGoogle() async {
    if (AppConfig.googleWebClientId.isEmpty) {
      throw const ApiError('Thiếu GOOGLE_WEB_CLIENT_ID khi build app (xem app/README.md)');
    }
    await _ensureInit();
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate(scopeHint: const ['email', 'profile']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const SignInCancelled();
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const ApiError(
          'Đăng nhập Google chưa được cấu hình (thiếu OAuth client Android cho app). Liên hệ quản trị viên.',
        );
      }
      throw ApiError('Đăng nhập Google lỗi: ${e.description ?? e.code.name}');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const ApiError('Google không trả về ID token');
    try {
      final res = await _api.auth.authGoogle(body: GoogleLoginDto(idToken: idToken));
      await _storage.save(access: res.accessToken, refresh: res.refreshToken);
      return res.user;
    } catch (e) {
      await _google.signOut();
      throw ApiError.from(e);
    }
  }

  Future<MeDto> getMe() async {
    try {
      return await _api.users.usersGetMe();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<MeDto> updateProfile({
    required String name,
    required PositionValue position,
    int? shirtNumber,
    String? area,
    String? avatarKey,
  }) async {
    try {
      return await _api.users.usersUpdateMe(
        body: UpdateMeDto(
          name: name,
          position: PositionKnown(position),
          shirtNumber: shirtNumber,
          area: area,
          avatarKey: avatarKey,
        ),
      );
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<void> signOut() async {
    final refresh = await _storage.readRefresh();
    if (refresh != null) {
      try {
        await _api.auth.authLogout(body: RefreshDto(refreshToken: refresh));
      } catch (_) {
        // Mất mạng vẫn cho đăng xuất trên máy
      }
    }
    await _storage.clear();
    try {
      await _ensureInit();
      await _google.signOut();
    } catch (_) {}
  }

  Future<bool> teamStepSkipped() => _storage.readTeamStepSkipped();
  Future<void> skipTeamStep() => _storage.setTeamStepSkipped();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiProvider), ref.watch(tokenStorageProvider)),
);
