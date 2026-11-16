import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/core/theme/tokens.dart';
import 'package:san7/core/widgets/app_toast.dart';

Future<void> _pump(WidgetTester t) => t.pumpWidget(
  MaterialApp(
    scaffoldMessengerKey: AppToast.messengerKey,
    home: const Scaffold(body: SizedBox()),
  ),
);

void main() {
  for (final c in <(ToastType, String, IconData, Color)>[
    (ToastType.success, 'Đã lưu', Icons.check_circle_rounded, AppColors.green),
    (ToastType.error, 'Lỗi mạng', Icons.error_rounded, AppColors.red),
    (ToastType.warning, 'Cẩn thận', Icons.warning_amber_rounded, AppColors.warnSoft),
    (ToastType.info, 'Thông tin', Icons.info_rounded, AppColors.darkCard),
  ]) {
    testWidgets('toast ${c.$1.name} hiện đúng nội dung, icon, màu', (t) async {
      await _pump(t);
      AppToast.show(c.$1, c.$2);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text(c.$2), findsOneWidget);
      expect(find.byIcon(c.$3), findsOneWidget);
      final bar = t.widget<SnackBar>(find.byKey(ValueKey('toast-${c.$1.name}')));
      expect(bar.backgroundColor, c.$4);
    });
  }

  testWidgets('toast tự ẩn sau 4 giây và toast mới thay toast cũ', (t) async {
    await _pump(t);
    AppToast.error('Một');
    await t.pump();
    AppToast.success('Hai');
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Một'), findsNothing);
    expect(find.text('Hai'), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Hai'), findsNothing);
  });
}
