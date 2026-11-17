import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Chat giữa hai đội trong một trận.
class ChatRepository {
  ChatRepository(this._api);
  final San7Api _api;

  /// Đánh dấu đã xem tới tin mới nhất (`POST /v1/matches/:id/chat/read`).
  Future<void> markRead(String matchId) =>
      apiCall(() => _api.chat.chatReadRead(matchId: matchId));

  /// Tin mới nhất trước.
  Future<MessagePageDto> list(String matchId, {String? cursor}) =>
      apiCall(() => _api.chat.chatList(matchId: matchId, cursor: cursor, limit: 30));

  Future<MessageDto> send(String matchId, String body) => apiCall(
    () => _api.chat.chatSend(
      matchId: matchId,
      body: SendMessageDto(body: body),
    ),
  );
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiProvider)),
);
