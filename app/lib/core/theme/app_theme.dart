import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Theme phong cách Apple theo bản vẽ. iOS dùng font hệ thống, Android dùng Inter.
/// [fontFamily] chỉ dùng trong test (thay Inter tải từ mạng).
ThemeData buildAppTheme({String? fontFamily}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.redBright,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );

  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  final textTheme =
      (isIOS || fontFamily != null ? base.textTheme : GoogleFonts.interTextTheme(base.textTheme))
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text);

  return base.copyWith(
    textTheme: textTheme.copyWith(
      // Tiêu đề lớn của màn (34/30px, đậm, chữ hơi khít)
      displaySmall: textTheme.displaySmall?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        height: 1.12,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 17, letterSpacing: -0.2),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, letterSpacing: -0.2),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 13, color: AppColors.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.group)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: AppColors.textSecondary),
    ),
  );
}
