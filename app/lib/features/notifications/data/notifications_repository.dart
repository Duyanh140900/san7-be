import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Thông báo trong app.
class NotificationsRepository {
  NotificationsRepository(this._api);
  final San7Api _api;

  Future<NotificationPageDto> list({NotificationCategoryValue? category, String? cursor}) =>
      apiCall(
        () => _api.notifications.notificationsList(
          category: category == null ? null : NotificationCategoryKnown(category),
          cursor: cursor,
          limit: 50,
        ),
      );

  Future<int> unreadCount() =>
      apiCall(() => _api.notifications.notificationsUnreadCount()).then((r) => r.count);

  /// [ids] vắng = đánh dấu tất cả.
  Future<void> markRead([List<String>? ids]) =>
      apiCall(() => _api.notifications.notificationsMarkRead(body: MarkReadDto(ids: ids)));
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiProvider)),
);

final unreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).unreadCount(),
);

final notificationsProvider = FutureProvider.autoDispose
    .family<NotificationPageDto, NotificationCategoryValue?>(
      (ref, category) => ref.watch(notificationsRepositoryProvider).list(category: category),
    );
