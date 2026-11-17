import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/features/media/data/media_repository.dart';
import 'package:san7/features/me/presentation/post_schedules_tab.dart';
import 'package:san7/features/post_create/presentation/widgets/image_attach_strip.dart';
import 'package:san7/features/posts/presentation/post_widgets.dart';

PostScheduleDto schedule(PostScheduleDtoStatus status, {bool weekly = false}) => PostScheduleDto(
  id: 's1',
  teamId: 't1',
  scheduledAt: DateTime.utc(2026, 11, 20, 3, 0),
  repeatWeekly: weekly,
  status: status,
  post: CreatePostDto(
    type: PostType.findOpponent,
    startAt: DateTime.utc(2026, 11, 22, 12, 0),
    endAt: DateTime.utc(2026, 11, 22, 13, 30),
    pitchName: 'Sân Mỹ Đình',
    level: TeamLevel.tb,
  ),
);

void main() {
  testWidgets('ScheduleList hiện lịch chờ đăng, lặp tuần, bỏ lịch đã huỷ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScheduleList(
              schedules: [
                schedule(PostScheduleDtoStatus.scheduled, weekly: true),
                schedule(PostScheduleDtoStatus.cancelled),
              ],
              onCancel: (_) async {},
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('lặp hằng tuần'), findsOneWidget);
    expect(find.text('Sân Mỹ Đình'), findsOneWidget);
    expect(find.text('Huỷ lịch'), findsOneWidget);
  });

  testWidgets('ScheduleList trống hiện trạng thái trống', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleList(schedules: const [], onCancel: (_) async {}),
        ),
      ),
    );
    expect(find.text('Chưa có kèo nào hẹn giờ đăng'), findsOneWidget);
  });

  testWidgets('Huỷ lịch hỏi xác nhận rồi gọi onCancel', (tester) async {
    var called = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleList(
            schedules: [schedule(PostScheduleDtoStatus.scheduled)],
            onCancel: (_) async => called++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Huỷ lịch'));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ lịch đăng?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(called, 0);
  });

  testWidgets('ImageAttachStrip hiện đếm ảnh và ẩn nút thêm khi đủ', (tester) async {
    final img = PickedImage(
      name: 'a.png',
      bytes: Uint8List.fromList(_png),
      contentType: CreateUploadDtoContentType.imagePng,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageAttachStrip(images: [img], max: 1, onChanged: (_) {}),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Thêm ảnh'), findsNothing);
    expect(find.bySemanticsLabel('Xoá ảnh 1'), findsOneWidget);
  });

  test('contentTypeOf nhận jpg/png/webp, từ chối heic và khác', () {
    expect(MediaRepository.contentTypeOf('x.JPG'), CreateUploadDtoContentType.imageJpeg);
    expect(MediaRepository.contentTypeOf('x.heic'), isNull);
    expect(MediaRepository.contentTypeOf('x.gif'), isNull);
  });

  test('sniffContentType nhận theo nội dung, không tin đuôi tên', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final webp = Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]);
    final heic = Uint8List.fromList([0, 0, 0, 0x18, ...'ftypheic'.codeUnits]);
    expect(MediaRepository.sniffContentType(jpeg), CreateUploadDtoContentType.imageJpeg);
    expect(MediaRepository.sniffContentType(png), CreateUploadDtoContentType.imagePng);
    expect(MediaRepository.sniffContentType(webp), CreateUploadDtoContentType.imageWebp);
    expect(MediaRepository.sniffContentType(heic), isNull);
  });

  testWidgets('PostMediaStrip hiện ảnh theo số lượng', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostMediaStrip(
            media: [PostMediaDto(key: 'k', url: 'http://127.0.0.1:1/x.png')],
          ),
        ),
      ),
    );
    expect(find.byType(PostMediaStrip), findsOneWidget);
  });
}

const _png = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xFF,
  0xFF,
  0x3F,
  0x00,
  0x05,
  0xFE,
  0x02,
  0xFE,
  0xA7,
  0x35,
  0x81,
  0x84,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
