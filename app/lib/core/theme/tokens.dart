import 'package:flutter/widgets.dart';

/// Màu "Floodlight Night" (bản vẽ v2, màn 00). Không dùng mã màu rời trong widget.
/// Tên cũ (primary, text, surface...) giữ nguyên và đã map sang bảng màu tối
/// để màn chưa đổi giao diện không vỡ.
abstract final class AppColors {
  // ---- Bảng màu mới (dùng cho màn mới) ----
  /// Lime đèn pha: màu chính, nút
  static const lime = Color(0xFFC8FF2E);
  static const limeHover = Color(0xFFD6FF5C);

  /// Sân đêm: nền
  static const night = Color(0xFF06110B);

  /// Cỏ: thẻ nổi, mặt sân
  static const grass = Color(0xFF11402A);

  /// Kèo nóng (cam), Cúp vàng, Đội nhà (xanh)
  static const hot = Color(0xFFFF6B2C);
  static const hotText = Color(0xFFFFB38F);
  static const trophy = Color(0xFFFFC83D);
  static const home = Color(0xFF2F7BFF);
  static const homeText = Color(0xFF8DB6FF);

  /// Thẻ đỏ (lỗi, huỷ)
  static const card = Color(0xFFFF5A5F);

  /// Bề mặt: thẻ (#0E1F16), ô icon / nút phụ (#15291E), khối xanh đậm (#0B2416), dải tin (#0A1A11)
  static const surfaceCard = Color(0xFF0E1F16);
  static const surfaceHigh = Color(0xFF15291E);
  static const surfaceDeep = Color(0xFF0B2416);
  static const surfaceStrip = Color(0xFF0A1A11);

  /// Chữ: chính, nội dung, phụ, mờ
  static const textMain = Color(0xFFF2F7F3);
  static const textBody = Color(0xFFDCE7DF);
  static const textMuted = Color(0xFFB7C8BD);
  static const textDim = Color(0xFF8FA597);

  /// Chữ đặt trên nền lime / vàng / cam
  static const ink = Color(0xFF06110B);

  /// Viền mảnh trên nền tối (trắng 8% / 12% / 14%)
  static const line = Color(0x14FFFFFF);
  static const lineStrong = Color(0x1FFFFFFF);
  static const lineButton = Color(0x24FFFFFF);

  // ---- Tên cũ, map sang bảng tối ----
  static const primary = lime;
  static const primaryHover = limeHover;
  static const primarySoft = Color(0x24C8FF2E);
  static const primarySoftText = lime;

  static const text = textMain;
  static const textSecondary = textDim;
  static const background = night;
  static const surface = surfaceCard;
  static const border = line;
  static const pillBorder = lineStrong;

  static const green = Color(0xFF34D17A);
  static const greenBright = Color(0xFF34D17A);
  static const greenSoft = Color(0x2434D17A);
  static const greenSoftText = Color(0xFF6BE6A0);

  static const red = card;
  static const redBright = card;
  static const orange = hot;
  static const darkCard = surfaceHigh;

  /// Dải "đang chờ" (vàng) và nhãn cam (tuyển người, quỹ)
  static const warnSoft = Color(0x24FFC83D);
  static const warnText = trophy;
  static const orangeSoft = Color(0x29FF6B2C);
  static const orangeText = hotText;

  /// Nền cột được gợi ý (màn so sánh)
  static const primaryTint = Color(0x0FC8FF2E);

  /// Đường kẻ trong nhóm
  static const divider = Color(0x0FFFFFFF);

  /// Bóng đổ của ghim/nút nổi và thẻ trượt trên bản đồ
  static const shadow = Color(0x80000000);
  static const shadowSoft = Color(0x4D000000);

  /// Vàng của cầu thủ hay nhất / cầu thủ của tháng
  static const gold = trophy;
  static const goldSoft = Color(0x24FFC83D);
  static const goldText = trophy;

  /// Sao đánh giá
  static const star = trophy;

  /// Nền ô icon mục Hoạt động (màn Cá nhân)
  static const activityOrange = Color(0xFFB4501F);
  static const activityGold = Color(0xFFB88A1E);

  /// Xám của mục bị vô hiệu (khung giờ đã qua/hết sân, ghim hết chỗ)
  static const disabled = Color(0xFF4A5D52);

  /// Chữ phụ trên nền tối
  static const onDarkMuted = textMuted;

  /// Sọc cỏ sáng hơn màu cỏ sân
  static const pitchStripe = Color(0xFF145031);

  /// Màu cỏ sân (ảnh sân giả lập)
  static const pitch = grass;

  /// Vạch sân
  static const pitchLine = Color(0x80E8FFD0);
}

/// Tên font đã đóng gói trong assets/fonts (khai báo ở pubspec.yaml).
abstract final class AppFonts {
  /// Barlow Condensed ExtraBold Italic: tiêu đề, tỉ số, số liệu
  static const display = 'BarlowCondensed';

  /// Be Vietnam Pro: nội dung
  static const body = 'BeVietnamPro';
}

/// Kiểu chữ dùng chung. Tiêu đề/số liệu: [display], còn lại dùng textTheme.
abstract final class AppText {
  /// Tiêu đề, số liệu: Barlow Condensed ExtraBold Italic, viết HOA khi hiển thị (gọi `.toUpperCase()`).
  static TextStyle display(double size, {Color color = AppColors.textMain, double? height}) =>
      TextStyle(
        fontFamily: AppFonts.display,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        fontSize: size,
        height: height ?? 1.0,
        color: color,
      );

  /// Tỉ số, đồng hồ: Barlow Condensed ExtraBold dựng thẳng, số cùng bề rộng.
  static TextStyle score(double size, {Color color = AppColors.lime}) => TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.normal,
    fontSize: size,
    height: 1.0,
    color: color,
    letterSpacing: 2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Nhãn nhỏ viết hoa cách chữ ("LOGO & WORDMARK")
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.textDim,
  );
}

abstract final class AppRadius {
  static const card = 18.0;
  static const group = 14.0;
  static const pill = 999.0;

  /// Bản vẽ v2: nút 16–18, thẻ 24, thẻ lớn/ảnh bìa 28
  static const button = 16.0;
  static const tile = 24.0;
  static const hero = 28.0;
}

abstract final class AppSizes {
  /// Vùng bấm tối thiểu
  static const tapTarget = 44.0;
  static const screenPadding = 24.0;
  static const tabBarHeight = 84.0;
}
