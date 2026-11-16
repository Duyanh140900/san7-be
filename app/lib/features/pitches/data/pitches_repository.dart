import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Tìm sân và khung giờ trống.
class PitchesRepository {
  PitchesRepository(this._api);
  final San7Api _api;

  Future<List<PitchDto>> list({
    double? lat,
    double? lng,
    double? radiusKm,
    String? q,
    required String date,
    String? at,
    PitchesListAmenityValue? amenity,
  }) => apiCall(
    () => _api.pitches.pitchesList(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
      q: q,
      date: date,
      at: at,
      amenity: amenity == null ? null : PitchesListAmenityKnown(amenity),
    ),
  ).then((r) => r.items);

  Future<PitchDto> detail(String id, {required String date, double? lat, double? lng}) =>
      apiCall(() => _api.pitches.pitchesDetail(pitchId: id, date: date, lat: lat, lng: lng));
}

final pitchesRepositoryProvider = Provider<PitchesRepository>(
  (ref) => PitchesRepository(ref.watch(apiProvider)),
);

/// Đặt sân của đội: giữ chỗ → xác nhận (trả tại sân), đổi giờ, huỷ.
class BookingsRepository {
  BookingsRepository(this._api);
  final San7Api _api;

  Future<BookingDto> hold(String teamId, String pitchId, DateTime startAt) => apiCall(
    () => _api.bookings.bookingsHold(
      teamId: teamId,
      body: CreateBookingDto(pitchId: pitchId, startAt: startAt),
    ),
  );

  Future<BookingDto> get(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsGet(teamId: teamId, bookingId: bookingId));

  Future<List<BookingDto>> upcoming(String teamId) =>
      apiCall(() => _api.bookings.bookingsList(teamId: teamId));

  Future<BookingDto> confirm(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsConfirm(teamId: teamId, bookingId: bookingId));

  Future<BookingDto> cancel(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsCancel(teamId: teamId, bookingId: bookingId));

  Future<BookingDto> reschedule(String teamId, String bookingId, DateTime startAt) => apiCall(
    () => _api.bookings.bookingsReschedule(
      teamId: teamId,
      bookingId: bookingId,
      body: RescheduleBookingDto(startAt: startAt),
    ),
  );
}

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.watch(apiProvider)),
);
