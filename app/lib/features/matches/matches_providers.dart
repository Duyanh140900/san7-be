import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/exports.dart';
import 'data/matches_repository.dart';

typedef MatchKey = ({String teamId, String matchId});

final matchDetailProvider = FutureProvider.autoDispose.family<MatchDetailDto, MatchKey>(
  (ref, k) => ref.watch(matchesRepositoryProvider).detail(k.teamId, k.matchId),
);

/// Hồ sơ đội (công khai): thành tích, uy tín, nhận xét, trận gần đây.
final teamProfileProvider = FutureProvider.autoDispose.family<TeamProfileDto, String>(
  (ref, teamId) => ref.watch(matchesRepositoryProvider).profile(teamId),
);

typedef HonorsKey = ({String month, String? teamId});

/// Bảng vàng của một tháng ("2026-11"), kèm danh hiệu của đội nếu có [teamId].
final honorsProvider = FutureProvider.autoDispose.family<HonorsDto, HonorsKey>(
  (ref, k) => ref.watch(matchesRepositoryProvider).honors(month: k.month, teamId: k.teamId),
);

typedef FinesKey = ({String teamId, String period});

final finesProvider = FutureProvider.autoDispose.family<FinesDto, FinesKey>(
  (ref, k) => ref.watch(matchesRepositoryProvider).fines(k.teamId, period: k.period),
);

/// Tiền sân một đội phải trả theo tỉ số (khớp backend `matchFees`): thắng trả [ratioWin]%,
/// thua trả phần còn lại, hoà chia đôi. Null khi kèo không chia tiền sân.
int? matchFee({
  required int? pitchPrice,
  required int? ratioWin,
  required int? ratioLose,
  required int home,
  required int away,
  required bool iAmHome,
}) {
  if (pitchPrice == null || pitchPrice <= 0 || ratioWin == null || ratioLose == null) return null;
  if (home == away) {
    final h = pitchPrice ~/ 2;
    return iAmHome ? h : pitchPrice - h;
  }
  final winner = pitchPrice * ratioWin ~/ 100;
  final iWin = iAmHome ? home > away : away > home;
  return iWin ? winner : pitchPrice - winner;
}
