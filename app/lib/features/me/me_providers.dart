import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import 'data/me_repository.dart';

/// Kèo của tôi theo trạng thái (null = tất cả). Một trang đầu, đủ cho danh sách ngắn.
final myPostsProvider = FutureProvider.autoDispose.family<FeedPageDto, PostStatus?>(
  (ref, status) => ref.watch(meRepositoryProvider).myPosts(status: status),
);

final notificationSettingsProvider = FutureProvider.autoDispose<NotificationSettingsDto>(
  (ref) => ref.watch(meRepositoryProvider).notificationSettings(),
);
