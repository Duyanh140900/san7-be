import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/format.dart';
import '../../../core/realtime/realtime_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../matches/matches_providers.dart';
import '../../posts/presentation/post_widgets.dart';
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
        _add(
          MessageDto.fromJson(withoutNulls(jsonDecode(jsonEncode(raw))) as Map<String, dynamic>),
        );
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

  void _add(MessageDto m) {
    if (!mounted || _messages.any((x) => x.id == m.id)) return;
    setState(() => _messages.insert(0, m));
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHeader(backLabel: 'Quay lại', title: opponent?.name ?? 'Nhắn tin'),
            if (m != null) _PinnedMatch(match: m),
            Expanded(child: _body(myId)),
            _QuickReplies(onTap: _send),
            _Composer(controller: _input, sending: _sending, onSend: () => _send(_input.text)),
          ],
        ),
      ),
    );
  }

  Widget _body(String? myId) {
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
      itemBuilder: (_, i) =>
          ChatBubble(message: _messages[i], mine: _messages[i].sender.id == myId),
    );
  }
}

class _PinnedMatch extends StatelessWidget {
  const _PinnedMatch({required this.match});
  final MatchDetailDto match;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.group),
    ),
    child: Text(
      ['Kèo ${Fmt.slot(match.startAt)}', ?match.location].join(' · '),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// Bong bóng chat: của tôi bên phải (xanh), của đội bạn bên trái (trắng).
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, required this.mine});
  final MessageDto message;
  final bool mine;

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
                borderRadius: BorderRadius.circular(18),
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
                Fmt.time(message.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
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
              backgroundColor: AppColors.primarySoft,
              labelStyle: const TextStyle(color: AppColors.primarySoftText),
              side: BorderSide.none,
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
