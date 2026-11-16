import 'package:flutter/widgets.dart';

/// Màu lấy từ bản vẽ (PLAN mục 10). Không dùng mã màu rời trong widget.
abstract final class AppColors {
  static const primary = Color(0xFF0066CC);
  static const primaryHover = Color(0xFF0071E3);
  static const primarySoft = Color(0xFFE8F0FB);
  static const primarySoftText = Color(0xFF0058B0);

  static const text = Color(0xFF1D1D1F);
  static const textSecondary = Color(0xFF6E6E73);
  static const background = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE0E0E0);
  static const pillBorder = Color(0xFFD2D2D7);

  static const green = Color(0xFF248A3D);
  static const greenBright = Color(0xFF34C759);
  static const greenSoft = Color(0xFFE9F6EC);
  static const greenSoftText = Color(0xFF1F7A35);

  static const red = Color(0xFFC4000F);
  static const redBright = Color(0xFFD70015);
  static const orange = Color(0xFFFF9500);
  static const darkCard = Color(0xFF272729);

  /// Dải "đang chờ" (vàng) và nhãn cam (tuyển người, quỹ) trong bản vẽ
  static const warnSoft = Color(0xFFFFF6D6);
  static const warnText = Color(0xFF7A5A00);
  static const orangeSoft = Color(0xFFFDF0E6);
  static const orangeText = Color(0xFFA04800);

  /// Nền cột được gợi ý (màn so sánh)
  static const primaryTint = Color(0xFFF2F7FD);

  /// Đường kẻ trong nhóm
  static const divider = Color(0xFFF0F0F0);

  /// Bóng đổ của ghim/nút nổi và thẻ trượt trên bản đồ
  static const shadow = Color(0x29000000);
  static const shadowSoft = Color(0x1A000000);

  /// Xám của mục bị vô hiệu (khung giờ đã qua/hết sân, ghim hết chỗ)
  static const disabled = Color(0xFFAEAEB2);

  /// Chữ phụ trên nền tối
  static const onDarkMuted = Color(0xFFCCCCCC);

  /// Sọc cỏ sáng hơn màu cỏ sân
  static const pitchStripe = Color(0xFF34994C);

  /// Màu cỏ sân (ảnh sân giả lập)
  static const pitch = Color(0xFF2F8F46);
}

abstract final class AppRadius {
  static const card = 18.0;
  static const group = 14.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  /// Vùng bấm tối thiểu
  static const tapTarget = 44.0;
  static const screenPadding = 24.0;
  static const tabBarHeight = 84.0;
}
