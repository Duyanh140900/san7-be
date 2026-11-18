import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

class HeadToHeadDto {
  const HeadToHeadDto({
    this.wins = 1,
    this.draws = 0,
    this.losses = 1,
    this.lastMatchNote = 'Gần đây',
  });

  final int wins;
  final int draws;
  final int losses;
  final String? lastMatchNote;

  factory HeadToHeadDto.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HeadToHeadDto();
    final played = json['played'] as int?;
    final note = json['lastMatchNote'] as String? ??
        (played != null ? 'Đã gặp $played trận' : null);
    return HeadToHeadDto(
      wins: json['wins'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      lastMatchNote: note,
    );
  }
}

class PublicPlayerDto {
  const PublicPlayerDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.position,
    this.shirtNumber,
    this.team,
    required this.stats,
    this.recentMatches = const [],
    this.headToHead = const HeadToHeadDto(),
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final String? position;
  final int? shirtNumber;
  final ({String id, String name, String? crestColor})? team;
  final ({int goals, int assists, int matches, int mvps}) stats;
  final List<({String matchId, DateTime startAt, int goals, int assists, bool mvp})> recentMatches;
  final HeadToHeadDto headToHead;

  factory PublicPlayerDto.fromJson(Map<String, dynamic> json) {
    final t = json['team'] as Map<String, dynamic>?;
    final s = json['stats'] as Map<String, dynamic>? ?? {};
    final rm = json['recentMatches'] as List<dynamic>? ?? [];
    return PublicPlayerDto(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Cầu thủ',
      avatarUrl: json['avatarUrl'] as String?,
      position: json['position'] as String?,
      shirtNumber: json['shirtNumber'] as int?,
      team: t != null
          ? (
              id: t['id'] as String? ?? '',
              name: t['name'] as String? ?? '',
              crestColor: t['crestColor'] as String?,
            )
          : null,
      stats: (
        goals: s['goals'] as int? ?? 0,
        assists: s['assists'] as int? ?? 0,
        matches: s['matches'] as int? ?? 0,
        mvps: s['mvps'] as int? ?? 0,
      ),
      recentMatches: rm.map((m) {
        final map = m as Map<String, dynamic>;
        return (
          matchId: map['matchId'] as String? ?? '',
          startAt: DateTime.tryParse(map['startAt'] as String? ?? '') ?? DateTime.now(),
          goals: map['goals'] as int? ?? 0,
          assists: map['assists'] as int? ?? 0,
          mvp: map['mvp'] as bool? ?? false,
        );
      }).toList(),
      headToHead: HeadToHeadDto.fromJson(json['headToHead'] as Map<String, dynamic>?),
    );
  }
}

class PlayersRepository {
  PlayersRepository(this._dio);
  final Dio _dio;

  Future<PublicPlayerDto> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/players/$id');
    return PublicPlayerDto.fromJson(res.data!);
  });
}

final playersRepositoryProvider = Provider<PlayersRepository>(
  (ref) => PlayersRepository(ref.watch(dioProvider)),
);

final playerProfileProvider = FutureProvider.autoDispose.family<PublicPlayerDto, String>(
  (ref, id) => ref.watch(playersRepositoryProvider).get(id),
);
