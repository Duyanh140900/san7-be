import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/features/post_create/presentation/widgets/publish_schedule_picker.dart';

Widget host({
  bool scheduled = false,
  bool repeat = false,
  ValueChanged<bool>? onScheduled,
  VoidCallback? onDate,
  VoidCallback? onTime,
  ValueChanged<bool>? onRepeat,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: PublishSchedulePicker(
        scheduled: scheduled,
        // 01:00 UTC = 08:00 giờ VN
        publishUtc: DateTime.utc(2026, 11, 21, 1, 0),
        repeatWeekly: repeat,
        onScheduledChanged: onScheduled ?? (_) {},
        onPickDate: onDate ?? () {},
        onPickTime: onTime ?? () {},
        onRepeatChanged: onRepeat ?? (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('Đăng ngay: chỉ có hai lựa chọn, ẩn ngày, giờ và lặp lại', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('Đăng ngay'), findsOneWidget);
    expect(find.text('Hẹn lịch'), findsOneWidget);
    expect(find.text('Ngày đăng'), findsNothing);
    expect(find.text('Giờ đăng'), findsNothing);
    expect(find.text('Lặp lại hàng tuần'), findsNothing);
  });

  testWidgets('Bấm Hẹn lịch báo true, bấm Đăng ngay báo false', (tester) async {
    final calls = <bool>[];
    await tester.pumpWidget(host(scheduled: true, onScheduled: calls.add));
    await tester.tap(find.text('Đăng ngay'));
    await tester.pumpWidget(host(onScheduled: calls.add));
    await tester.tap(find.text('Hẹn lịch'));
    expect(calls, [false, true]);
  });

  testWidgets('Hẹn lịch: hiện ngày, giờ VN, công tắc lặp lại; chạm gọi đúng callback', (
    tester,
  ) async {
    var date = 0;
    var time = 0;
    bool? repeat;
    await tester.pumpWidget(
      host(
        scheduled: true,
        onDate: () => date++,
        onTime: () => time++,
        onRepeat: (v) => repeat = v,
      ),
    );
    expect(find.text('Ngày đăng'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('Lặp lại hàng tuần'), findsOneWidget);
    expect(find.textContaining('dời giờ đá thêm 7 ngày'), findsOneWidget);

    await tester.tap(find.text('Ngày đăng'));
    await tester.tap(find.text('Giờ đăng'));
    await tester.tap(find.byType(Switch));
    expect((date, time, repeat), (1, 1, true));
  });
}
