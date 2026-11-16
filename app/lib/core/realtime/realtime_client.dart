import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../features/auth/data/auth_repository.dart';
import '../../features/matches/matches_providers.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/pitches/pitches_providers.dart';
import '../../features/posts/posts_providers.dart';
import '../../features/team/team_providers.dart';
import '../auth/auth_controller.dart';
import '../auth/token_storage.dart';
import '../config.dart';

/// Kết nối Socket.IO tới /v1/socket. Xác thực bằng access token mỗi lần (re)connect.
class RealtimeClient {
  RealtimeClient({required this.storage, required this.refreshSession});

  final TokenStorage storage;

  /// Gọi một API bất kỳ để interceptor tự refresh token khi server báo hết hạn.
  final Future<void> Function() refreshSession;

  io.Socket? _socket;
  String? _teamId;
  final _events = StreamController<(String, Map<String, dynamic>)>.broadcast();

  Stream<(String, Map<String, dynamic>)> get events => _events.stream;

  static const _teamEvents = [
    'attendance.updated',
    'events.changed',
    'funds.changed',
    'members.changed',
    // Gửi tới room user:{id}
    'notification.new',
  ];

  void connect() {
    if (_socket != null) return;
    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setPath('/v1/socket')
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuthFn((cb) async => cb({'token': await storage.readAccess()}))
          .build(),
    );
    socket.onConnect((_) => _joinTeam());
    socket.on('auth:error', (_) async {
      try {
        await refreshSession();
        socket.connect();
      } catch (_) {
        // Phiên hết hạn hẳn: tầng auth sẽ đưa về màn đăng nhập
      }
    });
    for (final name in _teamEvents) {
      socket.on(name, (data) {
        if (data is Map) _events.add((name, Map<String, dynamic>.from(data)));
      });
    }
    _socket = socket..connect();
  }

  void setTeam(String? teamId) {
    if (_teamId == teamId) return;
    final old = _teamId;
    _teamId = teamId;
    if (old != null) _socket?.emit('team:leave', {'teamId': old});
    _joinTeam();
  }

  void _joinTeam() {
    final id = _teamId;
    if (id != null && _socket?.connected == true) _socket!.emit('team:join', {'teamId': id});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _events.close();
  }
}

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    storage: ref.watch(tokenStorageProvider),
    refreshSession: () => ref.read(authRepositoryProvider).getMe(),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Giữ kết nối realtime theo trạng thái đăng nhập và làm mới dữ liệu đội khi có sự kiện.
/// Được watch ở khung tab (AppShell).
final teamRealtimeSyncProvider = Provider<void>((ref) {
  final client = ref.watch(realtimeClientProvider);

  void apply(AuthState auth) {
    if (auth is AuthSignedIn) {
      client.connect();
    } else {
      client.disconnect();
    }
  }

  apply(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => apply(next));
  client.setTeam(ref.read(currentTeamIdProvider));
  ref.listen(currentTeamIdProvider, (_, next) => client.setTeam(next), fireImmediately: false);

  final sub = client.events.listen((e) {
    final (name, data) = e;
    if (name == 'notification.new') {
      ref.invalidate(unreadCountProvider);
      ref.invalidate(notificationsProvider);
      // Thông báo về kèo: làm mới các màn kèo đang mở
      final payload = data['payload'];
      if (payload is Map && payload['postId'] is String) {
        ref.invalidate(postDetailProvider(payload['postId'] as String));
        ref.invalidate(postRequestsProvider);
        ref.invalidate(requestDetailProvider);
      }
      if (payload is Map && payload['matchId'] is String) {
        ref.invalidate(matchDetailProvider);
        ref.invalidate(teamProfileProvider);
        ref.invalidate(honorsProvider);
      }
      if (payload is Map && payload['bookingId'] is String) {
        ref.invalidate(bookingProvider);
        ref.invalidate(teamBookingsProvider);
        ref.invalidate(pitchDetailProvider);
        if (payload['teamId'] is String) {
          ref.invalidate(upcomingEventsProvider(payload['teamId'] as String));
        }
      }
      if (data['type'] == 'request.accepted' && payload is Map && payload['teamId'] is String) {
        ref.invalidate(upcomingEventsProvider(payload['teamId'] as String));
      }
      return;
    }
    final teamId = data['teamId'] as String?;
    if (teamId == null) return;
    switch (name) {
      case 'attendance.updated' || 'events.changed':
        ref.invalidate(upcomingEventsProvider(teamId));
        ref.invalidate(eventDetailProvider);
      case 'funds.changed':
        ref.invalidate(fundSummaryProvider(teamId));
      case 'members.changed':
        ref.invalidate(membersProvider(teamId));
        ref.invalidate(teamDetailProvider(teamId));
        // Chỉ tải lại /me khi thay đổi liên quan tới chính tôi (vai trò, bị mời ra)
        final auth = ref.read(authControllerProvider);
        final affected = (data['userIds'] as List?)?.cast<String>();
        if (auth is AuthSignedIn && (affected == null || affected.contains(auth.me.id))) {
          ref.read(authControllerProvider.notifier).reloadMe().ignore();
        }
    }
  });
  ref.onDispose(sub.cancel);
});
