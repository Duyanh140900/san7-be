import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/team_crest.dart';
import '../../team/team_providers.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'post_widgets.dart';

/// Màn 9 · Xác nhận đối nhận kèo (đội đăng kèo) / theo dõi yêu cầu đã gửi (đội nhận).
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.teamId, required this.requestId});
  final String teamId;
  final String requestId;

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  Timer? _tick;
  bool _busy = false;

  RequestKey get _key => (teamId: widget.teamId, requestId: widget.requestId);

  @override
  void initState() {
    super.initState();
    // Đếm ngược thời gian tự huỷ
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _refreshAll(String postId) {
    ref.invalidate(requestDetailProvider(_key));
    ref.invalidate(postDetailProvider(postId));
    ref.invalidate(feedProvider);
    ref.invalidate(upcomingEventsProvider(widget.teamId));
  }

  Future<void> _run(String postId, Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (!mounted) return;
    setState(() => _busy = false);
    _refreshAll(postId);
  }

  Future<void> _accept(RequestDetailDto d) => _run(
    d.post.id,
    () => ref.read(postsRepositoryProvider).accept(widget.teamId, widget.requestId),
    'Đã chốt kèo với ${d.request.team.name}',
  );

  Future<void> _decline(RequestDetailDto d) async {
    final yes = await _confirm(
      'Từ chối ${d.request.team.name}?',
      'Kèo của bạn vẫn hiện trên Bảng tin cho đội khác nhận.',
      'Từ chối',
    );
    if (yes) {
      await _run(
        d.post.id,
        () => ref.read(postsRepositoryProvider).decline(widget.teamId, widget.requestId),
        'Đã từ chối',
      );
    }
  }

  Future<void> _cancel(RequestDetailDto d) async {
    final yes = await _confirm(
      'Huỷ yêu cầu nhận kèo?',
      '${d.post.team.name} sẽ được báo là đội bạn đã huỷ.',
      'Huỷ yêu cầu',
    );
    if (yes) {
      await _run(
        d.post.id,
        () => ref.read(postsRepositoryProvider).cancel(widget.teamId, widget.requestId),
        'Đã huỷ yêu cầu',
      );
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Không')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(requestDetailProvider(_key));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const DetailHeader(backLabel: 'Quay lại', title: 'Nhận kèo'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(requestDetailProvider(_key).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    AsyncView(
                      value: detail,
                      onRetry: () => ref.invalidate(requestDetailProvider(_key)),
                      data: (d) => _Content(detail: d),
                    ),
                  ],
                ),
              ),
            ),
            if (detail.value case final d?) _bottom(d),
          ],
        ),
      ),
    );
  }

  Widget _bottom(RequestDetailDto d) {
    final owner = d.side == RequestDetailDtoSide.owner;
    final status = d.request.status;
    if (d.canRespond && owner) {
      return BottomActionBar(
        children: [
          FilledButton(
            onPressed: _busy ? null : () => _accept(d),
            child: Text(
              d.post.type == PostType.passPitch ? 'Chấp nhận nhượng sân' : 'Chấp nhận kèo',
            ),
          ),
          SoftButton(
            label: 'Từ chối',
            color: AppColors.red,
            onPressed: _busy ? null : () => _decline(d),
          ),
        ],
      );
    }
    if (d.canRespond && !owner) {
      return BottomActionBar(
        children: [
          SoftButton(
            label: 'Huỷ yêu cầu',
            color: AppColors.red,
            onPressed: _busy ? null : () => _cancel(d),
          ),
        ],
      );
    }
    if (status == RequestStatus.accepted) {
      final currentTeam = ref.watch(currentTeamIdProvider);
      return BottomActionBar(
        children: [
          FilledButton(
            onPressed: () => d.eventId != null && currentTeam == widget.teamId
                ? context.push(Routes.teamEvent(d.eventId!))
                : context.go(Routes.teamSchedule),
            child: const Text('Xem lịch đội'),
          ),
        ],
      );
    }
    if (!owner && d.post.status.isOpen) {
      return BottomActionBar(
        children: [
          SoftButton(
            label: 'Gửi lại nhận kèo',
            onPressed: () => context.pushReplacement(Routes.postRequest(d.post.id)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});
  final RequestDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.request;
    final p = detail.post;
    final owner = detail.side == RequestDetailDtoSide.owner;
    // Đội "bên kia" so với người đang xem
    final other = owner
        ? (name: r.team.name, color: r.team.crestColor, area: r.team.area, level: r.team.level)
        : (name: p.team.name, color: p.team.crestColor, area: p.team.area, level: p.team.level);
    final proposed = r.ratioWin != null && r.ratioLose != null;
    final win = r.ratioWin ?? p.ratioWin;
    final split = p.deal == PostDeal.split
        ? feeSplit(p.pitchPrice, win, r.ratioLose ?? p.ratioLose)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusBanner(detail: detail),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            children: [
              TeamCrest(name: other.name, color: other.color, width: 72),
              const SizedBox(height: 10),
              Text(
                other.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  other.area,
                  'Trình độ ${Labels.level(other.level)}',
                  if (owner) '${r.team.memberCount} thành viên',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              if (owner) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _Stat('${r.team.matchesPlayed}', 'Trận đã đá'),
                      _Stat('${r.peopleCount}', 'Số người'),
                      _Stat('${r.team.headToHead}', 'Đã gặp'),
                    ],
                  ),
                ),
              ],
              if (r.message != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Text('“${r.message}”', style: const TextStyle(fontSize: 15, height: 1.45)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owner ? 'Kèo của bạn' : 'Kèo của ${p.team.name}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _Kv('Thời gian', Fmt.eventTime(p.startAt, p.endAt)),
              _Kv('Sân', p.pitchName ?? 'Chưa có sân'),
              _Kv('Trình độ', Labels.level(p.level)),
              if (p.type == PostType.findOpponent)
                _Kv(
                  'Tỷ lệ',
                  proposed
                      ? 'Đề xuất ${r.ratioWin} – ${r.ratioLose} (kèo ${Labels.ratio(p.ratioWin, p.ratioLose, p.deal)})'
                      : Labels.ratio(p.ratioWin, p.ratioLose, p.deal) ?? '—',
                  highlight: proposed,
                ),
              if (split != null)
                _Kv('Tiền sân', 'Thắng ${Fmt.money(split.win)} · Thua ${Fmt.money(split.lose)}'),
              if (p.type == PostType.passPitch && p.pitchPrice != null)
                _Kv('Giá nhượng', Fmt.money(p.pitchPrice!)),
              if (!owner) _Kv('Đội bạn đến', '${r.peopleCount} người'),
            ],
          ),
        ),
        if (owner && detail.otherPending.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => context.push(Routes.postCompare(p.team.id, p.id)),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  TeamAvatarStack(
                    teams: [
                      for (final t in detail.otherPending.take(3))
                        (name: t.name, color: t.crestColor),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${detail.otherPending.length} đội khác cũng muốn nhận kèo này',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const Text('So sánh', style: TextStyle(fontSize: 15, color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.detail});
  final RequestDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.request;
    final owner = detail.side == RequestDetailDtoSide.owner;
    final left = Fmt.remaining(r.expiresAt.difference(DateTime.now()));
    final otherName = owner ? r.team.name : detail.post.team.name;
    return switch (r.status) {
      RequestStatusKnown(value: RequestStatusValue.pending) => StatusBanner(
        tone: BannerTone.waiting,
        icon: const AppIcon(AppIcons.clock, color: Color(0xFF7A5A00)),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: owner
                    ? 'Đang chờ bạn xác nhận · tự huỷ sau '
                    : 'Đã gửi. Đang chờ $otherName xác nhận, tự huỷ sau ',
              ),
              TextSpan(
                text: left,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
      RequestStatusKnown(value: RequestStatusValue.accepted) => StatusBanner(
        tone: BannerTone.success,
        icon: const AppIcon(AppIcons.checkCircle, color: AppColors.greenSoftText),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Đã chốt kèo! ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: detail.post.type == PostType.passPitch
                    ? 'Sân đã chuyển cho ${owner ? otherName : 'đội bạn'}.'
                    : 'Trận đã vào lịch đội, anh em có thể điểm danh.',
              ),
            ],
          ),
        ),
      ),
      RequestStatusKnown(value: RequestStatusValue.declined) => StatusBanner(
        tone: BannerTone.neutral,
        child: Text(
          owner
              ? 'Đã từ chối $otherName.'
              : detail.post.status.isOpen
              ? '$otherName đã từ chối yêu cầu.'
              : 'Kèo của $otherName đã có đối hoặc đã đóng.',
        ),
      ),
      RequestStatusKnown(value: RequestStatusValue.expired) => StatusBanner(
        tone: BannerTone.neutral,
        child: Text('Yêu cầu đã hết hạn vì $otherName chưa trả lời kịp.'),
      ),
      RequestStatusKnown(value: RequestStatusValue.cancelled) => StatusBanner(
        tone: BannerTone.neutral,
        child: Text(owner ? '$otherName đã huỷ yêu cầu.' : 'Đội bạn đã huỷ yêu cầu.'),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    ),
  );
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 40),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              color: highlight ? AppColors.orange : AppColors.text,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}
