import 'package:flutter_test/flutter_test.dart';
import 'package:san7/api/exports.dart';
import 'package:san7/core/format.dart';
import 'package:san7/core/labels.dart';
import 'package:san7/features/matches/matches_providers.dart';
import 'package:san7/features/matches/presentation/team_profile_screen.dart';

int? fee({
  required int home,
  required int away,
  required bool iAmHome,
  int win = 40,
  int lose = 60,
}) => matchFee(
  pitchPrice: 600000,
  ratioWin: win,
  ratioLose: lose,
  home: home,
  away: away,
  iAmHome: iAmHome,
);

void main() {
  group('matchFee (khớp backend)', () {
    test('đội thắng trả theo tỷ lệ thắng, đội thua trả phần còn lại', () {
      expect(fee(home: 3, away: 2, iAmHome: true), 240000);
      expect(fee(home: 3, away: 2, iAmHome: false), 360000);
      expect(fee(home: 0, away: 1, iAmHome: true), 360000);
      expect(fee(home: 0, away: 1, iAmHome: false), 240000);
    });

    test('hoà chia đôi và tổng luôn bằng tiền sân', () {
      expect(fee(home: 1, away: 1, iAmHome: true), 300000);
      final h = matchFee(
        pitchPrice: 500001,
        ratioWin: 40,
        ratioLose: 60,
        home: 2,
        away: 2,
        iAmHome: true,
      )!;
      final a = matchFee(
        pitchPrice: 500001,
        ratioWin: 40,
        ratioLose: 60,
        home: 2,
        away: 2,
        iAmHome: false,
      )!;
      expect(h + a, 500001);
    });

    test('thua trả sân (0–100) và kèo không chia tiền sân', () {
      expect(fee(home: 2, away: 0, iAmHome: true, win: 0, lose: 100), 0);
      expect(fee(home: 2, away: 0, iAmHome: false, win: 0, lose: 100), 600000);
      expect(
        matchFee(
          pitchPrice: null,
          ratioWin: null,
          ratioLose: null,
          home: 1,
          away: 0,
          iAmHome: true,
        ),
        isNull,
      );
    });
  });

  test('nhãn đánh giá tiếng Việt, nhãn lạ giữ nguyên khoá', () {
    expect(Labels.reviewTag('on_time'), 'Đúng giờ');
    expect(Labels.reviewTag('fair_pay'), 'Trả tiền sòng phẳng');
    expect(Labels.reviewTag('xyz'), 'xyz');
    expect(Labels.reviewTags.length, 5);
  });

  test('điểm số kiểu Việt và màu kết quả', () {
    expect(Fmt.rating(4.9), '4,9');
    expect(Fmt.rating(5), '5,0');
    expect(outcomeStyle('W').$2, 'T');
    expect(outcomeStyle('L').$2, 'B');
    expect(outcomeStyle('D').$2, 'H');
  });

  test('trạng thái kết quả nhận từ API', () {
    expect(MatchDetailDtoResultState.awaitingMe, isNot(MatchDetailDtoResultState.confirmed));
  });
}
