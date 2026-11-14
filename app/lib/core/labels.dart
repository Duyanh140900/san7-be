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
    TeamRoleKnown(value: TeamRoleValue.captain) => 'Đội trưởng',
    TeamRoleKnown(value: TeamRoleValue.vice) => 'Đội phó',
    TeamRoleKnown(value: TeamRoleValue.treasurer) => 'Thủ quỹ',
    TeamRoleKnown(value: TeamRoleValue.member) => 'Thành viên',
    TeamRoleUnknown(:final rawValue) => rawValue,
  };

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
