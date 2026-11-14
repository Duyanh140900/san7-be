import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/san7_api.dart';
import '../auth/token_storage.dart';
import '../config.dart';
import 'auth_interceptor.dart';

/// Báo cho tầng auth khi phiên hết hạn hẳn (refresh thất bại).
final sessionExpiredProvider = NotifierProvider<SessionExpired, int>(SessionExpired.new);

class SessionExpired extends Notifier<int> {
  @override
  int build() => 0;
  void fire() => state++;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      storage: ref.watch(tokenStorageProvider),
      onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).fire(),
    ),
  );
  return dio;
});

/// Client sinh từ OpenAPI. Chỉ dùng trong repository, không gọi trực tiếp từ widget.
final apiProvider = Provider<San7Api>((ref) => San7Api(ref.watch(dioProvider)));
