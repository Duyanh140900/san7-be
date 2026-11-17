import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Cá nhân: Kèo của tôi và cài đặt thông báo.
class MeRepository {
  MeRepository(this._api, this._dio);
  final San7Api _api;
  final Dio _dio;

  /// `PATCH /v1/teams/:teamId/post-schedules/:id`: sửa giờ (HH:mm giờ VN), thứ (0 = Chủ nhật)
  /// hoặc tạm dừng. [resume] gửi `pausedUntil: null` (DTO sinh sẵn không gửi được null nên
  /// riêng trường hợp này gọi Dio).
  Future<PostScheduleDto> updateSchedule(
    String teamId,
    String scheduleId, {
    String? time,
    int? weekday,
    DateTime? pausedUntil,
    bool resume = false,
  }) => apiCall(() async {
    if (resume) {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/v1/teams/$teamId/post-schedules/$scheduleId',
        data: {'pausedUntil': null},
      );
      return PostScheduleDto.fromJson(res.data!);
    }
    return _api.postSchedules.postSchedulesUpdate(
      teamId: teamId,
      scheduleId: scheduleId,
      body: UpdatePostScheduleDto(time: time, weekday: weekday, pausedUntil: pausedUntil),
    );
  });

  Future<FeedPageDto> myPosts({PostStatus? status, String? cursor}) => apiCall(
    () => _api.posts.postsMyPosts(status: status, cursor: cursor, limit: 20),
  );

  Future<List<PostScheduleDto>> postSchedules(String teamId) =>
      apiCall(() => _api.postSchedules.postSchedulesList(teamId: teamId));

  Future<PostScheduleDto> createSchedule(
    String teamId,
    CreatePostScheduleDto body,
  ) => apiCall(
    () => _api.postSchedules.postSchedulesCreate(teamId: teamId, body: body),
  );

  Future<void> cancelSchedule(String teamId, String scheduleId) => apiCall(
    () => _api.postSchedules.postSchedulesCancel(
      teamId: teamId,
      scheduleId: scheduleId,
    ),
  );

  Future<NotificationSettingsDto> notificationSettings() =>
      apiCall(() => _api.users.usersGetNotificationSettings());

  Future<NotificationSettingsDto> updateNotificationSettings(
    UpdateNotificationSettingsDto body,
  ) => apiCall(() => _api.users.usersUpdateNotificationSettings(body: body));
}

final meRepositoryProvider = Provider<MeRepository>(
  (ref) => MeRepository(ref.watch(apiProvider), ref.watch(dioProvider)),
);
