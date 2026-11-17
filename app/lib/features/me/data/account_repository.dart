import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Xoá tài khoản (`DELETE /v1/me`). Gọi Dio trực tiếp cho tới khi client sinh lại có endpoint này.
class AccountRepository {
  AccountRepository(this._dio);
  final Dio _dio;

  /// 204 khi xoá xong; 409 `captain_must_transfer` ném [ApiError] có `code`.
  Future<void> deleteAccount() => apiCall(() => _dio.delete<void>('/v1/me'));
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(dioProvider)),
);
