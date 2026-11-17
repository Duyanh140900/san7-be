import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/team_crest.dart';
import '../../matches/matches_providers.dart';
import '../data/chat_repository.dart';

const chatQuickReplies = ['Gửi vị trí sân', 'Đổi giờ?', 'Đến muộn 10 phút'];

/// Socket không qua OmitNullInterceptor của REST nên phải bỏ trường null trước khi parse.
@visibleForTesting
Object? withoutNulls(Object? v) => switch (v) {
  Map() => <String, dynamic>{
    for (final e in v.entries)
      if (e.value != null) e.key as String: withoutNulls(e.value),
  },
  List() => <dynamic>[for (final x in v) withoutNulls(x)],
  _ => v,
};

/// Màn 21 · Nhắn tin giữa 2 đội (realtime qua Socket.IO, phòng match:{id}).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.teamId, required this.matchId});
  final String teamId;
  final String matchId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <MessageDto>[]; // mới nhất trước
  String? _cursor;
  bool _loading = true;
  bool _failed = false;
  bool _loadingMore = false;
  bool _sending = false;
  StreamSubscription<(String, Map<String, dynamic>)>? _sub;
  late final RealtimeClient _rt;

  @override
  void initState() {
    super.initState();
    _rt = ref.read(realtimeClientProvider);
    _rt.joinMatch(widget.matchId);
    _sub = _rt.events.listen((e) {
      final (name, data) = e;
      if (name != 'chat.message' || data['matchId'] != widget.matchId) return;
      final raw = data['message'];
      if (raw is! Map) return;
      try {
        final msg = MessageDto.fromJson(
          withoutNulls(jsonDecode(jsonEncode(raw))) as Map<String, dynamic>,
        );
        _add(msg);
        _markRead();
        _refreshReadState();
      } catch (_) {}
    });
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 160) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rt.leaveMatch(widget.matchId);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Tải lại trận để lấy `opponentLastReadAt` mới (hiện "Đã xem").
  void _refreshReadState() =>
      ref.invalidate(matchDetailProvider((teamId: widget.teamId, matchId: widget.matchId)));

  void _add(MessageDto m) {
    if (!mounted || _messages.any((x) => x.id == m.id)) return;
    setState(() => _messages.insert(0, m));
  }

  /// Báo đã xem tới tin mới nhất. Lỗi thì bỏ qua.
  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.matchId);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref.read(chatRepositoryProvider).list(widget.matchId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
      });
      _markRead();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await ref.read(chatRepositoryProvider).list(widget.matchId, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _messages.addAll(page.items.where((m) => !_messages.any((x) => x.id == m.id)));
        _cursor = page.nextCursor;
      });
    } catch (_) {
      // Lần cuộn sau sẽ thử lại
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await ref.read(chatRepositoryProvider).send(widget.matchId, body);
      _add(m);
      _refreshReadState();
      _input.clear();
    } catch (e) {
      if (mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (teamId: widget.teamId, matchId: widget.matchId);
    final match = ref.watch(matchDetailProvider(key));
    final auth = ref.watch(authControllerProvider);
    final myId = auth is AuthSignedIn ? auth.me.id : null;
    final m = match.value;
    final opponent = m == null ? null : (m.homeTeam.id == m.myTeamId ? m.awayTeam : m.homeTeam);
    final cancelled = m?.status == MatchStatus.cancelled;
    final lastRead = DateTime.tryParse('${m?.additionalProperties['opponentLastReadAt'] ?? ''}');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              opponent: opponent,
              captainName: m?.opponentCaptainName,
              captainPhone: m?.opponentCaptainPhone,
            ),
            if (m != null) _PinnedMatch(match: m),
            Expanded(child: _body(myId, lastRead)),
            if (cancelled)
              const _ReadOnlyNotice()
            else ...[
              _QuickReplies(onTap: _send),
              _Composer(controller: _input, sending: _sending, onSend: () => _send(_input.text)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(String? myId, DateTime? lastRead) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không tải được tin nhắn', style: TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có tin nhắn. Hãy chào đội bạn!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final mine = _messages[i].sender.id == myId;
        // Chỉ ghi "Đã xem" dưới tin cuối cùng của tôi mà đội bạn đã đọc.
        final seen =
            mine &&
            i == _messages.indexWhere((x) => x.sender.id == myId) &&
            lastRead != null &&
            !lastRead.isBefore(_messages[i].createdAt);
        return ChatBubble(message: _messages[i], mine: mine, seen: seen);
      },
    );
  }
}

/// Header màn 21: mũi tên quay lại, avatar đội bạn 38px, tên + phụ đề (khu vực · trình độ).
/// Phụ đề thêm tên đội trưởng; nút gọi chỉ hiện khi backend trả `captainPhone` (trận đã chốt).
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.opponent, this.captainName, this.captainPhone});
  final TeamBriefDto? opponent;
  final String? captainName;
  final String? captainPhone;

  @override
  Widget build(BuildContext context) {
    final t = opponent;
    final captain = captainName;
    final phone = captainPhone;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const AppIcon(AppIcons.back, size: 26, color: AppColors.primary),
          ),
          if (t != null) ...[
            TeamAvatar(name: t.name, color: t.crestColor, size: 38),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t?.name ?? 'Nhắn tin',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (t != null)
                  Text(
                    [
                      '${t.area} · ${Labels.level(t.level)}',
                      if (captain != null) 'ĐT $captain',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            IconButton(
              tooltip: 'Gọi đội trưởng',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

/// Thẻ kèo ghim: pill "Kèo", giờ · sân, trạng thái bên phải.
class _PinnedMatch extends StatelessWidget {
  const _PinnedMatch({required this.match});
  final MatchDetailDto match;

  static (String, Color) _status(MatchStatus s) => switch (s) {
    MatchStatusKnown(value: MatchStatusValue.finished) => ('Đã đá', AppColors.textSecondary),
    MatchStatusKnown(value: MatchStatusValue.cancelled) => ('Đã huỷ', AppColors.red),
    _ => ('Đã chốt', AppColors.greenSoftText),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _status(match.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.group),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              'Kèo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primarySoftText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [Fmt.slot(match.startAt), ?match.location].join(' · '),
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Bong bóng chat: của tôi bên phải (xanh), của đội bạn bên trái (trắng).
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.mine, this.seen = false});
  final MessageDto message;
  final bool mine;
  final bool seen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  message.sender.name,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 6),
                  bottomRight: Radius.circular(mine ? 6 : 18),
                ),
              ),
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: mine ? AppColors.surface : AppColors.text,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Text(
                seen ? '${Fmt.time(message.createdAt)} · Đã xem' : Fmt.time(message.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    color: AppColors.surface,
    child: const Text(
      'Trận đấu đã huỷ — chỉ có thể xem lại tin nhắn cũ',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
  );
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final t in chatQuickReplies)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(t),
              onPressed: () => onTap(t),
              backgroundColor: AppColors.surface,
              labelStyle: const TextStyle(fontSize: 14, color: AppColors.primary),
              side: const BorderSide(color: AppColors.pillBorder),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            ),
          ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: const InputDecoration(hintText: 'Nhập tin nhắn'),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: 'Gửi',
                  onPressed: onSend,
                  icon: const AppIcon(AppIcons.arrowUp, size: 24, color: AppColors.primary),
                ),
        ),
      ],
    ),
  );
}
