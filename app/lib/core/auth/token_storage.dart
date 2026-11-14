import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access/refresh token trong kho bảo mật của hệ điều hành.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _access = 'access_token';
  static const _refresh = 'refresh_token';
  static const _teamSkipped = 'team_step_skipped';

  String? _accessCache;

  Future<String?> readAccess() async => _accessCache ??= await _storage.read(key: _access);
  Future<String?> readRefresh() => _storage.read(key: _refresh);

  Future<void> save({required String access, required String refresh}) async {
    _accessCache = access;
    await _storage.write(key: _access, value: access);
    await _storage.write(key: _refresh, value: refresh);
  }

  Future<void> clear() async {
    _accessCache = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _teamSkipped);
  }

  Future<bool> readTeamStepSkipped() async => await _storage.read(key: _teamSkipped) == '1';
  Future<void> setTeamStepSkipped() => _storage.write(key: _teamSkipped, value: '1');
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
