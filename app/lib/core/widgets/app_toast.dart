import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

enum ToastType { success, error, warning, info }

/// Toast dùng chung (4 loại). Gọi được từ bất kỳ đâu, không cần BuildContext:
/// `AppToast.error('Có lỗi')`. [messengerKey] gắn vào MaterialApp.
abstract final class AppToast {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static const duration = Duration(seconds: 4);

  static void success(String message) => show(ToastType.success, message);
  static void error(String message) => show(ToastType.error, message);
  static void warning(String message) => show(ToastType.warning, message);
  static void info(String message) => show(ToastType.info, message);

  static void show(ToastType type, String message, {ScaffoldMessengerState? messenger}) {
    final m = messenger ?? messengerKey.currentState;
    if (m == null) return;
    final style = _styleOf(type);
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: ValueKey('toast-${type.name}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: style.background,
          duration: duration,
          dismissDirection: DismissDirection.horizontal,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.group)),
            side: style.border == null ? BorderSide.none : BorderSide(color: style.border!),
          ),
          content: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(style.icon, color: style.foreground, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: style.foreground, fontSize: 15, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static _ToastStyle _styleOf(ToastType type) => switch (type) {
    ToastType.success => const _ToastStyle(
      AppColors.green,
      Colors.white,
      Icons.check_circle_rounded,
    ),
    ToastType.error => const _ToastStyle(AppColors.red, Colors.white, Icons.error_rounded),
    ToastType.warning => const _ToastStyle(
      AppColors.warnSoft,
      AppColors.warnText,
      Icons.warning_amber_rounded,
      border: AppColors.orange,
    ),
    ToastType.info => const _ToastStyle(AppColors.darkCard, Colors.white, Icons.info_rounded),
  };
}

class _ToastStyle {
  const _ToastStyle(this.background, this.foreground, this.icon, {this.border});
  final Color background;
  final Color foreground;
  final IconData icon;
  final Color? border;
}
