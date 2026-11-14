import 'package:flutter_test/flutter_test.dart';
import 'package:san7/core/format.dart';

void main() {
  test('tiền VND có dấu chấm ngăn cách', () {
    expect(Fmt.money(0), '0đ');
    expect(Fmt.money(50000), '50.000đ');
    expect(Fmt.money(1250000), '1.250.000đ');
    expect(Fmt.money(-300000), '−300.000đ');
    expect(Fmt.signedMoney(200000), '+200.000đ');
    expect(Fmt.signedMoney(-1950000), '−1.950.000đ');
  });

  test('giờ hiển thị theo giờ Việt Nam bất kể múi giờ máy', () {
    // 12:00 UTC thứ Bảy = 19:00 giờ VN
    final start = DateTime.utc(2026, 11, 22, 12);
    final end = DateTime.utc(2026, 11, 22, 13, 30);
    expect(Fmt.eventTime(start, end), 'CN 22/11 · 19:00 – 20:30');
    // 18:00 UTC 30/11 = 01:00 ngày 1/12 giờ VN
    expect(Fmt.dayMonth(DateTime.utc(2026, 11, 30, 18)), '1/12');
  });

  test('đếm ngược theo ngày lịch VN', () {
    final now = DateTime.utc(2026, 11, 14, 3); // 10:00 VN 14/11
    expect(Fmt.countdown(DateTime.utc(2026, 11, 22, 12), now: now), 'còn 8 ngày');
    expect(Fmt.countdown(DateTime.utc(2026, 11, 14, 12), now: now), 'hôm nay');
    expect(Fmt.countdown(DateTime.utc(2026, 11, 15, 1), now: now), 'ngày mai');
  });

  test('kỳ quỹ và chữ cái đầu', () {
    expect(Fmt.currentPeriod(now: DateTime.utc(2026, 11, 30, 18)), '2026-12');
    expect(Fmt.periodLabel('2026-11'), 'tháng 11');
    expect(Fmt.initials('Đức Hùng'), 'ĐH');
    expect(Fmt.initials('Nguyễn Văn An'), 'VA');
    expect(Fmt.initials('An'), 'A');
    expect(Fmt.initials('Văn Nam (thử)'), 'VN');
  });
}
