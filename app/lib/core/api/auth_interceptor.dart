import 'package:dio/dio.dart';

import '../../api/exports.dart';
import '../auth/token_storage.dart';

/// Gắn access token vào request; gặp 401 thì refresh một lần rồi gửi lại.
/// QueuedInterceptor giữ các request khác chờ trong lúc đang refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.dio, required this.storage, required this.onSessionExpired});

  final Dio dio;
  final TokenStorage storage;
  final void Function() onSessionExpired;

  static const _retriedKey = 'auth_retried';

  bool _isAuthPath(String path) => path.startsWith('/v1/auth/');

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_isAuthPath(options.path)) {
      final token = await storage.readAccess();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || _isAuthPath(req.path) || req.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    // Request khác có thể đã refresh xong trong lúc request này chờ hàng đợi
    final current = await storage.readAccess();
    final sent = (req.headers['Authorization'] as String?)?.replaceFirst('Bearer ', '');
    if (current != null && current != sent) {
      await _retry(req, current, handler, err);
      return;
    }

    final refresh = await storage.readRefresh();
    if (refresh == null) {
      onSessionExpired();
      return handler.next(err);
    }
    try {
      // Dio riêng, không qua interceptor này
      final plain = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
      final pair = await AuthClient(plain).authRefresh(body: RefreshDto(refreshToken: refresh));
      await storage.save(access: pair.accessToken, refresh: pair.refreshToken);
      await _retry(req, pair.accessToken, handler, err);
      return;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await storage.clear();
        onSessionExpired();
      }
      return handler.next(err);
    }
  }

  Future<void> _retry(
    RequestOptions req,
    String token,
    ErrorInterceptorHandler handler,
    DioException original,
  ) async {
    req.headers['Authorization'] = 'Bearer $token';
    req.extra[_retriedKey] = true;
    try {
      handler.resolve(await dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
