import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// Theme tối "Floodlight Night" (bản vẽ v2). Font đóng gói trong assets, không tải mạng.
/// [fontFamily] chỉ dùng trong test (thay font đóng gói bằng font mặc định).
ThemeData buildAppTheme({String? fontFamily}) {
  final family = fontFamily ?? AppFonts.body;
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: family,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.night,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: AppColors.ink,
      secondary: AppColors.hot,
      onSecondary: AppColors.ink,
      tertiary: AppColors.trophy,
      surface: AppColors.surfaceCard,
      onSurface: AppColors.textMain,
      error: AppColors.card,
      onError: AppColors.ink,
      outline: AppColors.lineStrong,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: AppColors.divider,
  );

  final textTheme = base.textTheme.apply(
    fontFamily: family,
    bodyColor: AppColors.textMain,
    displayColor: AppColors.textMain,
  );

  // Tiêu đề lớn: Barlow Condensed ExtraBold Italic (chỉ khi dùng font đóng gói)
  TextStyle? display(TextStyle? s, double size) => fontFamily != null
      ? s?.copyWith(fontSize: size, fontWeight: FontWeight.w700)
      : s?.copyWith(
          fontFamily: AppFonts.display,
          fontSize: size,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          height: 1.0,
        );

  return base.copyWith(
    textTheme: textTheme.copyWith(
      displaySmall: display(textTheme.displaySmall, 40),
      headlineMedium: display(textTheme.headlineMedium, 34),
      headlineSmall: display(textTheme.headlineSmall, 26),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16, color: AppColors.textBody),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, color: AppColors.textBody),
      bodySmall: textTheme.bodySmall?.copyWith(fontSize: 13, color: AppColors.textDim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.ink,
        disabledBackgroundColor: AppColors.lime.withValues(alpha: 0.35),
        disabledForegroundColor: AppColors.ink.withValues(alpha: 0.6),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surfaceHigh,
        foregroundColor: AppColors.textMain,
        minimumSize: const Size(AppSizes.tapTarget, 54),
        side: const BorderSide(color: AppColors.lineButton),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.lime,
        minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.textMain),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.group)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: AppColors.textDim),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.lime),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
