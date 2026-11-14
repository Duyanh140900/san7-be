import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Lịch đội và điểm danh.
class EventsRepository {
  EventsRepository(this._api);
  final San7Api _api;

  Future<List<EventSummaryDto>> upcoming(String teamId) => apiCall(
    () => _api.events.eventsList(teamId: teamId, scope: EventsListScope.upcoming, limit: 20),
  );

  Future<EventDetailDto> detail(String teamId, String eventId) =>
      apiCall(() => _api.events.eventsDetail(teamId: teamId, eventId: eventId));

  Future<EventSummaryDto> create(String teamId, CreateEventDto body) =>
      apiCall(() => _api.events.eventsCreate(teamId: teamId, body: body));

  Future<void> remove(String teamId, String eventId) =>
      apiCall(() => _api.events.eventsRemove(teamId: teamId, eventId: eventId));

  Future<AttendanceCountsDto> setAttendance(
    String teamId,
    String eventId,
    AttendanceStatusValue status, {
    String? note,
  }) => apiCall(
    () => _api.events.eventsSetAttendance(
      teamId: teamId,
      eventId: eventId,
      body: SetAttendanceDto(status: AttendanceStatusKnown(status), note: note),
    ),
  );
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(apiProvider)),
);
