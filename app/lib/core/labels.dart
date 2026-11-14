import '../api/exports.dart';

/// Nhãn tiếng Việt cho các enum của API và danh sách khu vực.
abstract final class Labels {
  static const positions = <(PositionValue, String)>[
    (PositionValue.goalkeeper, 'Thủ môn'),
    (PositionValue.defender, 'Hậu vệ'),
    (PositionValue.midfielder, 'Tiền vệ'),
    (PositionValue.forward, 'Tiền đạo'),
  ];

  static const levels = <(TeamLevelValue, String)>[
    (TeamLevelValue.sieuYeu, 'Siêu Yếu'),
    (TeamLevelValue.yeu, 'Yếu'),
    (TeamLevelValue.tby, 'TBY'),
    (TeamLevelValue.tb, 'TB'),
    (TeamLevelValue.tbk, 'TBK'),
    (TeamLevelValue.gioi, 'Giỏi'),
  ];

  static String level(TeamLevel l) => switch (l) {
    TeamLevelKnown(:final value) => levels.firstWhere((e) => e.$1 == value).$2,
    TeamLevelUnknown(:final rawValue) => rawValue,
  };

  static String role(TeamRole r) => switch (r) {
    TeamRoleKnown(:final value) => roleOf(value),
    TeamRoleUnknown(:final rawValue) => rawValue,
  };

  static String roleOf(TeamRoleValue v) => switch (v) {
    TeamRoleValue.captain => 'Đội trưởng',
    TeamRoleValue.vice => 'Phó đội',
    TeamRoleValue.treasurer => 'Thủ quỹ',
    TeamRoleValue.member => 'Thành viên',
  };

  /// Thứ tự trong bộ chọn vai trò (như bản vẽ màn 19).
  static const rolePicker = [
    TeamRoleValue.member,
    TeamRoleValue.vice,
    TeamRoleValue.treasurer,
    TeamRoleValue.captain,
  ];

  static String? position(Position? p) => switch (p) {
    PositionKnown(:final value) => positions.firstWhere((e) => e.$1 == value).$2,
    PositionUnknown(:final rawValue) => rawValue,
    null => null,
  };

  /// "Tiền đạo · số 9"
  static String playerLine(Position? p, int? shirtNumber) =>
      [?position(p), if (shirtNumber != null) 'số $shirtNumber'].join(' · ');

  /// Khu vực Hà Nội (giai đoạn đầu). Sau này lấy từ API.
  static const areas = <String>[
    'Cầu Giấy',
    'Đống Đa',
    'Thanh Xuân',
    'Hà Đông',
    'Ba Đình',
    'Hai Bà Trưng',
    'Hoàng Mai',
    'Long Biên',
    'Nam Từ Liêm',
    'Bắc Từ Liêm',
    'Tây Hồ',
    'Hoàn Kiếm',
  ];
}
