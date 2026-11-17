import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Cá nhân: Kèo của tôi và cài đặt thông báo.
class MeRepository {
  MeRepository(this._api);
  final San7Api _api;

  Future<FeedPageDto> myPosts({PostStatus? status, String? cursor}) =>
      apiCall(() => _api.posts.postsMyPosts(status: status, cursor: cursor, limit: 20));

  Future<NotificationSettingsDto> notificationSettings() =>
      apiCall(() => _api.users.usersGetNotificationSettings());

  Future<NotificationSettingsDto> updateNotificationSettings(UpdateNotificationSettingsDto body) =>
      apiCall(() => _api.users.usersUpdateNotificationSettings(body: body));
}

final meRepositoryProvider = Provider<MeRepository>((ref) => MeRepository(ref.watch(apiProvider)));
