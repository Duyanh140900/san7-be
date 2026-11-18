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
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/system_state.dart';
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
    final lastRead = m?.opponentLastReadAt;
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
    if (_loading) return const Center(child: LoadingState(compact: true));
    if (_failed) {
      return Center(
        child: SingleChildScrollView(
          child: ErrorState(onRetry: _load, compact: true, message: 'Không tải được tin nhắn.'),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: EmptyState(
            title: 'Chưa có tin nhắn',
            message: 'Hãy chào đội bạn!',
            compact: true,
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          SquareIconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            child: const AppIcon(AppIcons.back, size: 22, color: AppColors.textMain),
          ),
          const SizedBox(width: 10),
          if (t != null) ...[
            TeamCrest(name: t.name, color: t.crestColor, width: 36),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (t != null)
                  Text(
                    [
                      if (captain != null) 'ĐT $captain',
                      '${t.area} · ${Labels.level(t.level)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(width: 8),
            SquareIconButton(
              tooltip: 'Gọi đội trưởng',
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              child: const Icon(Icons.call_outlined, size: 20, color: AppColors.textMain),
            ),
          ],
        ],
      ),
    );
  }
}
/// Thẻ kèo ghim: icon bóng, giờ · sân, chip trạng thái bên phải.
class _PinnedMatch extends StatelessWidget {
  const _PinnedMatch({required this.match});
  final MatchDetailDto match;

  static (String, Color, Color) _status(MatchStatus s) => switch (s) {
    MatchStatusKnown(value: MatchStatusValue.finished) => (
      'ĐÃ ĐÁ',
      AppColors.surfaceHigh,
      AppColors.textMuted,
    ),
    MatchStatusKnown(value: MatchStatusValue.cancelled) => (
      'ĐÃ HUỶ',
      AppColors.card.withValues(alpha: 0.16),
      AppColors.card,
    ),
    _ => ('ĐÃ CHỐT', AppColors.greenSoft, AppColors.greenSoftText),
  };

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _status(match.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const AppIcon(AppIcons.ball, size: 22, color: AppColors.lime),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kèo ${Fmt.slot(match.startAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (match.location != null)
                  Text(
                    match.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bong bóng chat: của tôi bên phải (lime), của đội bạn bên trái (xanh cỏ tối).
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
                  style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.lime : AppColors.surfaceHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.tile),
                  topRight: const Radius.circular(AppRadius.tile),
                  bottomLeft: Radius.circular(mine ? AppRadius.tile : 8),
                  bottomRight: Radius.circular(mine ? 8 : AppRadius.tile),
                ),
              ),
              child: Text(
                message.body,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: mine ? AppColors.ink : AppColors.textMain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Text(
                seen ? '${Fmt.time(message.createdAt)} · Đã xem' : Fmt.time(message.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textDim),
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
    color: AppColors.surfaceCard,
    child: const Text(
      'Trận đấu đã huỷ — chỉ có thể xem lại tin nhắn cũ',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: AppColors.textDim),
    ),
  );
}

class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final t in chatQuickReplies)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: () => onTap(t),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lime,
                      ),
                    ),
                  ),
                ),
              ),
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
    padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
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
        const SizedBox(width: 8),
        SizedBox(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          child: sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Material(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: const Center(
                      child: AppIcon(AppIcons.arrowUp, size: 22, color: AppColors.ink),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}