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

  /// GET /v1/pitches/free-slots: sân còn trống quanh tôi (mặc định từ giờ đến hết tối nay).
  Future<List<FreePitchSlotDto>> freeSlots({double? lat, double? lng}) =>
      apiCall(() => _api.pitches.pitchesFreeSlots(lat: lat, lng: lng));

  Future<PitchDto> detail(String id, {required String date, double? lat, double? lng}) =>
      apiCall(() => _api.pitches.pitchesDetail(pitchId: id, date: date, lat: lat, lng: lng));

  /// GET /v1/pitches/:id/reviews: danh sách đánh giá của sân.
  Future<List<PitchReviewDto>> reviews(String id) =>
      apiCall(() => _api.pitches.pitchesReviews(pitchId: id));

  /// POST /v1/pitches/:id/reviews: gửi đánh giá sân mới.
  Future<PitchReviewDto> createReview(
    String id, {
    required num stars,
    required num turf,
    required num lighting,
    required num lockerRoom,
    required num ownerPrice,
    List<String>? tags,
    String? comment,
    String? bookingId,
  }) => apiCall(
    () => _api.pitches.pitchesCreateReview(
      pitchId: id,
      body: CreatePitchReviewDto(
        stars: stars,
        turf: turf,
        lighting: lighting,
        lockerRoom: lockerRoom,
        ownerPrice: ownerPrice,
        tags: tags,
        comment: comment,
        bookingId: bookingId,
      ),
    ),
  );
}

final pitchesRepositoryProvider = Provider<PitchesRepository>(
  (ref) => PitchesRepository(ref.watch(apiProvider)),
);

/// Đặt sân của đội: giữ chỗ → xác nhận / cọc, đổi giờ, huỷ.
class BookingsRepository {
  BookingsRepository(this._api);
  final San7Api _api;

  Future<BookingDto> hold(
    String teamId,
    String pitchId,
    DateTime startAt, {
    List<CreateBookingDtoServicesItem>? services,
    String? note,
  }) => apiCall(
    () => _api.bookings.bookingsHold(
      teamId: teamId,
      body: CreateBookingDto(
        pitchId: pitchId,
        startAt: startAt,
        services: services,
        note: note,
      ),
    ),
  );

  Future<BookingDto> get(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsGet(teamId: teamId, bookingId: bookingId));

  Future<List<BookingDto>> past(String teamId) => apiCall(
    () => _api.bookings.bookingsList(teamId: teamId, scope: BookingsListScope.past),
  );

  Future<List<BookingDto>> upcoming(String teamId) =>
      apiCall(() => _api.bookings.bookingsList(teamId: teamId));

  Future<BookingDto> confirm(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsConfirm(teamId: teamId, bookingId: bookingId));

  /// POST /v1/bookings/:id/deposit-claim: kiểm tra / yêu cầu xác nhận cọc.
  Future<BookingDto> claimDeposit(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsClaimDeposit(teamId: teamId, bookingId: bookingId));

  Future<BookingDto> cancel(String teamId, String bookingId) =>
      apiCall(() => _api.bookings.bookingsCancel(teamId: teamId, bookingId: bookingId));

  Future<BookingDto> reschedule(String teamId, String bookingId, DateTime startAt) => apiCall(
    () => _api.bookings.bookingsReschedule(
      teamId: teamId,
      bookingId: bookingId,
      body: RescheduleBookingDto(startAt: startAt),
    ),
  );

  /// GET /v1/me/bookings/summary?year=: thống kê đặt sân cá nhân trong năm.
  Future<BookingSummaryDto> summary({int? year}) =>
      apiCall(() => _api.users.usersBookingSummary(year: year));
}

final bookingsRepositoryProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.watch(apiProvider)),
);
