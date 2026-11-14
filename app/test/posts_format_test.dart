import 'package:flutter_test/flutter_test.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/core/format.dart';
import 'package:san7/core/labels.dart';
import 'package:san7/features/posts/presentation/post_widgets.dart';

void main() {
  test('chia tiền sân theo tỷ lệ, đội thua trả phần còn lại', () {
    expect(feeSplit(600000, 40, 60), (win: 240000, lose: 360000));
    expect(feeSplit(null, 40, 60), isNull);
    expect(feeSplit(600000, null, null), isNull);
  });

  test('nhãn tỷ lệ: số khi chia tiền, tên kèo khi kèo nước/giao hữu', () {
    expect(Labels.ratio(40, 60, PostDeal.split), '40 – 60');
    expect(Labels.ratio(null, null, PostDeal.drinks), 'Kèo nước');
    expect(Labels.ratio(0, 100, PostDeal.loserPays), '0 – 100');
  });

  test('thời gian tương đối và thời gian còn lại', () {
    final now = DateTime.utc(2026, 11, 14, 10);
    expect(Fmt.ago(now.subtract(const Duration(seconds: 20)), now: now), 'Vừa xong');
    expect(Fmt.ago(now.subtract(const Duration(minutes: 12)), now: now), '12 phút trước');
    expect(Fmt.ago(now.subtract(const Duration(hours: 3)), now: now), '3 giờ trước');
    expect(Fmt.remaining(const Duration(minutes: 105)), '1 giờ 45 phút');
    expect(Fmt.remaining(const Duration(seconds: 30)), 'dưới 1 phút');
    expect(Fmt.slot(DateTime.utc(2026, 11, 21, 12)), 'T7 21/11 · 19:00');
  });
}
