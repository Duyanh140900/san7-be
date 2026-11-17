import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_call.dart';
import '../../../api/san7_api.dart';
import '../../../core/api/api_client.dart';

/// Xoá tài khoản (`DELETE /v1/me`).
class AccountRepository {
  AccountRepository(this._api);
  final San7Api _api;

  /// 204 khi xoá xong; 409 `captain_must_transfer` ném [ApiError] có `code`.
  Future<void> deleteAccount() => apiCall(() => _api.users.usersRemoveAccount());
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(apiProvider)),
);
