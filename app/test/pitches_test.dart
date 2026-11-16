import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/core/format.dart';
import 'package:san7/features/pitches/pitches_providers.dart';
import 'package:san7/features/pitches/presentation/pitch_widgets.dart';
import 'package:san7/features/pitches/presentation/pitches_screen.dart';

PitchSlotDto slot(String isoUtc, {int price = 600000, int free = 2, bool available = true}) =>
    PitchSlotDto(
      startAt: DateTime.parse(isoUtc),
      endAt: DateTime.parse(isoUtc).add(const Duration(minutes: 90)),
      price: price,
      free: free,
      total: 4,
      available: available,
    );

void main() {
  group('định dạng cho sân', () {
    test('khoảng cách: mét dưới 1 km, km một chữ số thập phân', () {
      expect(Fmt.distance(350), '350 m');
      expect(Fmt.distance(1230), '1,2 km');
      expect(Fmt.distance(15000), '15,0 km');
    });

    test('ngày theo giờ VN: tham số API, đầu ngày, nhãn tương đối', () {
      // 18:00 UTC ngày 21 = 01:00 giờ VN ngày 22
      final t = DateTime.utc(2026, 11, 21, 18);
      expect(Fmt.dateParam(t), '2026-11-22');
      expect(Fmt.vnDayStart(t), DateTime.utc(2026, 11, 21, 17));
      expect(Fmt.relativeDay(t, now: t), 'Hôm nay');
      expect(Fmt.relativeDay(t.add(const Duration(days: 1)), now: t), 'Ngày mai');
      expect(Fmt.relativeDay(t.add(const Duration(days: 3)), now: t), 'T4 25/11');
      expect(Fmt.longDay(t), 'Chủ nhật, 22/11');
    });

    test('bảy ngày tới bắt đầu từ hôm nay, mỗi ngày là 00:00 giờ VN', () {
      final days = nextDays(now: DateTime.utc(2026, 11, 21, 18));
      expect(days.length, 7);
      expect(days.first, DateTime.utc(2026, 11, 21, 17));
      expect(days.last, DateTime.utc(2026, 11, 27, 17));
    });

    test('tên ghim gọn: bỏ chữ "Sân bóng"/"Sân"', () {
      expect(shortPitchName('Sân bóng Phúc La'), 'Phúc La');
      expect(shortPitchName('Sân Kim Giang'), 'Kim Giang');
      expect(shortPitchName('Hà Đông Arena'), 'Hà Đông Arena');
    });
  });

  group('bộ lọc tìm sân', () {
    test('copyWith đổi từng trường và xoá được giờ/từ khoá', () {
      final s = PitchSearch(day: DateTime.utc(2026, 11, 21, 17));
      final a = s.copyWith(at: '19:00', q: 'arena', light: true);
      expect((a.at, a.q, a.light), ('19:00', 'arena', true));
      final b = a.copyWith(clearAt: true, clearQ: true);
      expect((b.at, b.q, b.light), (null, null, true));
      expect(s.useLocation, isTrue);
      expect(a.copyWith(useLocation: false).useLocation, isFalse);
    });
  });

  group('SlotGrid', () {
    testWidgets('hiện giá khung còn, "Hết sân" và "Đã qua"; chỉ khung còn chọn được', (
      tester,
    ) async {
      PitchSlotDto? picked;
      final future = DateTime.now().toUtc().add(const Duration(days: 2));
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlotGrid(
              slots: [
                slot(future.toIso8601String()),
                slot(
                  future.add(const Duration(hours: 2)).toIso8601String(),
                  free: 0,
                  available: false,
                ),
                slot(past.toIso8601String(), free: 4, available: false),
              ],
              selected: null,
              onSelect: (s) => picked = s,
            ),
          ),
        ),
      );
      expect(find.text('600.000đ'), findsOneWidget);
      expect(find.text('Hết sân'), findsOneWidget);
      expect(find.text('Đã qua'), findsOneWidget);

      await tester.tap(find.text('Hết sân'));
      await tester.tap(find.text('Đã qua'));
      expect(picked, isNull);
      await tester.tap(find.text('600.000đ'));
      expect(picked?.price, 600000);
    });
  });

  group('AmenityTags', () {
    testWidgets('hiện tên tiện ích bằng tiếng Việt', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AmenityTags([PitchDtoAmenitiesItem.light, PitchDtoAmenitiesItem.newTurf]),
          ),
        ),
      );
      expect(find.text('Đèn LED'), findsOneWidget);
      expect(find.text('Cỏ nhân tạo mới'), findsOneWidget);
    });
  });
}
