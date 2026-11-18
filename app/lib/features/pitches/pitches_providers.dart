import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../api/exports.dart';
import '../../core/format.dart';
import '../posts/posts_providers.dart';
import '../team/team_providers.dart';
import 'data/pitches_repository.dart';

/// Chỉ bật hộp thoại xin quyền một lần mỗi phiên (từ chối rồi thì không hỏi lại liên tục).
bool _askedLocationPermission = false;

/// Vị trí hiện tại của người dùng (null nếu tắt định vị hoặc không cấp quyền).
/// Lấy vị trí gần nhất đã biết trước cho nhanh. Màn bản đồ làm mới khi quay lại app
/// (xem PitchesScreen) nên bật quyền trong Cài đặt rồi quay lại là dùng được ngay.
final userLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && !_askedLocationPermission) {
      _askedLocationPermission = true;
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 4),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
});

/// Sân trống tối nay quanh tôi (khối trên Bảng tin).
final freeSlotsProvider = FutureProvider.autoDispose<List<FreePitchSlotDto>>((ref) async {
  final loc = await ref.watch(userLocationProvider.future);
  return ref.watch(pitchesRepositoryProvider).freeSlots(lat: loc?.latitude, lng: loc?.longitude);
});

/// Bộ lọc tìm sân (màn 3).
class PitchSearch {
  const PitchSearch({
    required this.day,
    this.at,
    this.q,
    this.light = false,
    this.within1km = false,
    this.useLocation = true,
  });

  /// Ngày muốn đá: thời điểm 00:00 giờ VN của ngày đó.
  final DateTime day;

  /// Giờ bắt đầu khung ("19:00"), null = mọi giờ.
  final String? at;
  final String? q;
  final bool light;
  final bool within1km;

  /// Tìm quanh vị trí của tôi (tắt thì liệt kê mọi sân, sắp theo tên).
  final bool useLocation;

  PitchSearch copyWith({
    DateTime? day,
    String? at,
    bool clearAt = false,
    String? q,
    bool clearQ = false,
    bool? light,
    bool? within1km,
    bool? useLocation,
  }) => PitchSearch(
    day: day ?? this.day,
    at: clearAt ? null : (at ?? this.at),
    q: clearQ ? null : (q ?? this.q),
    light: light ?? this.light,
    within1km: within1km ?? this.within1km,
    useLocation: useLocation ?? this.useLocation,
  );
}

class PitchSearchNotifier extends Notifier<PitchSearch> {
  @override
  PitchSearch build() => PitchSearch(day: Fmt.vnDayStart(DateTime.now()));

  void update(PitchSearch Function(PitchSearch s) f) => state = f(state);
}

final pitchSearchProvider = NotifierProvider<PitchSearchNotifier, PitchSearch>(
  PitchSearchNotifier.new,
);

/// Danh sách sân theo bộ lọc, gần nhất trước nếu có vị trí.
final pitchListProvider = FutureProvider.autoDispose<List<PitchDto>>((ref) async {
  final s = ref.watch(pitchSearchProvider);
  final loc = s.useLocation ? await ref.watch(userLocationProvider.future) : null;
  return ref
      .watch(pitchesRepositoryProvider)
      .list(
        lat: loc?.latitude,
        lng: loc?.longitude,
        radiusKm: loc == null ? null : (s.within1km ? 1 : 15),
        q: s.q,
        date: Fmt.dateParam(s.day),
        at: s.at,
        amenity: s.light ? PitchesListAmenityValue.light : null,
      );
});

typedef PitchDayKey = ({String id, String date});

final pitchDetailProvider = FutureProvider.autoDispose.family<PitchDto, PitchDayKey>((
  ref,
  k,
) async {
  final loc = ref.watch(userLocationProvider).value;
  return ref
      .watch(pitchesRepositoryProvider)
      .detail(k.id, date: k.date, lat: loc?.latitude, lng: loc?.longitude);
});

/// Danh sách đánh giá của sân (màn 32).
final pitchReviewsProvider = FutureProvider.autoDispose.family<List<PitchReviewDto>, String>(
  (ref, pitchId) => ref.watch(pitchesRepositoryProvider).reviews(pitchId),
);

typedef BookingKey = ({String teamId, String bookingId});

final bookingProvider = FutureProvider.autoDispose.family<BookingDto, BookingKey>(
  (ref, k) => ref.watch(bookingsRepositoryProvider).get(k.teamId, k.bookingId),
);

/// Lượt đặt sắp tới của đội (dùng khi đăng kèo từ sân đã đặt).
final teamBookingsProvider = FutureProvider.autoDispose.family<List<BookingDto>, String>(
  (ref, teamId) => ref.watch(bookingsRepositoryProvider).upcoming(teamId),
);

/// Lịch sử đặt sân (các lượt đã qua) của đội.
final teamPastBookingsProvider = FutureProvider.autoDispose.family<List<BookingDto>, String>(
  (ref, teamId) => ref.watch(bookingsRepositoryProvider).past(teamId),
);

/// Thống kê đặt sân cá nhân trong năm (màn 31).
final bookingSummaryProvider = FutureProvider.autoDispose.family<BookingSummaryDto, int?>(
  (ref, year) => ref.watch(bookingsRepositoryProvider).summary(year: year),
);

/// Đội dùng để đặt sân: đội đang xem nếu tôi quản lý nó, không thì đội quản lý đầu tiên.
final bookingTeamProvider = Provider<MyTeamDto?>((ref) {
  final managed = ref.watch(managedTeamsProvider);
  if (managed.isEmpty) return null;
  final current = ref.watch(currentTeamIdProvider);
  return managed.firstWhere((t) => t.teamId == current, orElse: () => managed.first);
});
