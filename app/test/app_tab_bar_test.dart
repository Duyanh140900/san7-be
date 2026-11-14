import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/core/theme/tokens.dart';
import 'package:san7/core/widgets/app_shell.dart';

void main() {
  testWidgets('thanh tab có đủ 5 mục và gọi đúng hành động', (tester) async {
    int? branch;
    var created = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppTabBar(
            currentBranch: 0,
            onBranch: (i) => branch = i,
            onCreatePost: () => created++,
          ),
        ),
      ),
    );

    for (final label in ['Bảng tin', 'Đặt sân', 'Đội', 'Bảng vàng']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Đăng kèo'), findsOneWidget);

    // Tab đang chọn tô màu primary
    final active = tester.widget<Text>(find.text('Bảng tin'));
    expect(active.style?.color, AppColors.primary);

    await tester.tap(find.text('Đặt sân'));
    expect(branch, 1);
    await tester.tap(find.text('Đội'));
    expect(branch, 2);
    await tester.tap(find.text('Bảng vàng'));
    expect(branch, 3);
    await tester.tap(find.bySemanticsLabel('Đăng kèo'));
    expect(created, 1);
  });
}
