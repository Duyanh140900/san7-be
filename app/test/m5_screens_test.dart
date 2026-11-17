import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/features/chat/presentation/chat_screen.dart';
import 'package:san7/features/me/presentation/me_screen.dart';

MessageDto msg(String body) => MessageDto(
  id: 'm1',
  matchId: 'x',
  teamId: 't',
  body: body,
  sender: const ChatSenderDto(id: 'u2', name: 'Tiến Linh'),
  createdAt: DateTime.utc(2026, 11, 20, 12, 0),
);

void main() {
  testWidgets('ChatBubble của đội bạn hiện tên người gửi và giờ VN', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: msg('Đến muộn 10 phút'), mine: false)),
      ),
    );
    expect(find.text('Tiến Linh'), findsOneWidget);
    expect(find.text('Đến muộn 10 phút'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
  });

  testWidgets('ChatBubble của tôi không hiện tên', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ChatBubble(message: msg('Ok'), mine: true)),
      ),
    );
    expect(find.text('Tiến Linh'), findsNothing);
  });

  testWidgets('Dòng cài đặt thông báo đổi công tắc', (tester) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationSwitchRow(
            title: 'Cộng đồng',
            value: false,
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch));
    expect(changed, isTrue);
  });

  testWidgets('MeRow destructive không có mũi tên', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeRow(title: 'Đăng xuất', destructive: true, onTap: () {}),
        ),
      ),
    );
    expect(find.text('›'), findsNothing);
  });
}
