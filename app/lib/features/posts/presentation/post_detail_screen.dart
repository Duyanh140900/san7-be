import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/team_crest.dart';
import '../../../core/widgets/ticket_card.dart';
import '../../chat/presentation/chat_launcher.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'application_widgets.dart';
import 'community_widgets.dart';
import 'post_widgets.dart';

const _weekdaysLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// Màn 03 · Chi tiết kèo v2 "Floodlight Night".
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(postDetailProvider(postId).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    AsyncView(
                      value: post,
                      onRetry: () => ref.invalidate(postDetailProvider(postId)),
                      data: (d) => _Body(detail: d),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});
  final PostDetailDto detail;
  PostDto get post => detail.post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final managed = ref.watch(managedTeamsProvider);
    final canRequest =
        post.type != PostType.recruit &&
        post.status.isOpen &&
        post.startAt.isAfter(DateTime.now()) &&
        managed.any((t) => t.teamId != post.team.id);
    final split = post.deal == PostDeal.split
        ? feeSplit(post.pitchPrice, post.ratioWin, post.ratioLose)
        : null;

    final isUpcoming = post.startAt.isAfter(DateTime.now()) && post.status.isOpen;
    final singleMedia = post.media.isNotEmpty ? post.media.first.url : null;

    final dateLine =
        '${_weekdaysLong[post.startAt.weekday - 1]} · ${post.startAt.day}/${post.startAt.month} · 90 phút';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Banner / Media Header
        Stack(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceDeep,
                image: singleMedia != null
                    ? DecorationImage(
                        image: NetworkImage(singleMedia),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.night.withValues(alpha: 0.4),
                      AppColors.night.withValues(alpha: 0.1),
                      AppColors.night,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SquareIconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed),
                    child: const AppIcon(AppIcons.back, size: 22, color: AppColors.textMain),
                  ),
                  Row(
                    children: [
                      SquareIconButton(
                        tooltip: 'Chia sẻ',
                        onPressed: () => showToast(context, 'Đã sao chép liên kết kèo'),
                        child: const Icon(Icons.share_outlined, size: 20, color: AppColors.textMain),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (post.pitchName != null)
              Positioned(
                bottom: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.night.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    post.pitchName!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ),
            if (isUpcoming)
              Positioned(
                bottom: 12,
                right: 16,
                child: CountdownPill(target: post.startAt),
              ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Team Row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push(Routes.teamProfile(post.team.id)),
                    child: TeamCrest(name: post.team.name, color: post.team.crestColor, width: 44),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(Routes.teamProfile(post.team.id)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.team.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Text('★ 4,9', style: TextStyle(color: AppColors.trophy, fontSize: 13, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              Text(
                                '· Uy tín · ${Fmt.ago(post.createdAt)}',
                                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  StatusChip(
                    post.type == PostType.recruit
                        ? StatusKind.recruit
                        : StatusKind.findOpponent,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Post Body
              if (post.body != null && post.body!.isNotEmpty) ...[
                Text(
                  post.body!,
                  style: const TextStyle(fontSize: 15, height: 1.55, color: AppColors.textBody),
                ),
                const SizedBox(height: 16),
              ],

              // TicketCard "VÉ VÀO TRẬN"
              TicketCard(
                time: Fmt.time(post.startAt),
                dateLine: dateLine,
                stats: [
                  (label: 'Trình độ', value: Labels.level(post.level)),
                  (
                    label: 'Tỷ lệ',
                    value: Labels.ratio(post.ratioWin, post.ratioLose, post.deal) ?? '50–50'
                  ),
                  (
                    label: 'Thua trả',
                    value: split != null
                        ? Fmt.money(split.lose)
                        : (post.pitchPrice != null ? Fmt.money(post.pitchPrice!) : '—')
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Sân bóng card
              if (post.pitchName != null) ...[
                _PitchRow(
                  name: post.pitchName!,
                  area: post.area,
                  lat: detail.venueLat?.toDouble(),
                  lng: detail.venueLng?.toDouble(),
                ),
                const SizedBox(height: 14),
              ],

              // Đội nhận kèo list preview
              if (post.requestCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(AppRadius.tile),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          for (final t in detail.requestTeams.take(3)) ...[
                            TeamCrest(name: t.name, color: t.crestColor, width: 28),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${post.requestCount} đội đã gửi nhận kèo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ),
                      if (detail.canManage)
                        TextButton(
                          onPressed: () => context.push(Routes.postCompare(post.team.id, post.id)),
                          child: const Text('So sánh'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Comments & Reactions
              PostCommunityBar(
                postId: post.id,
                canManageComments: detail.canManage,
              ),
              if (post.type == PostType.recruit && detail.canManage) ...[
                const SizedBox(height: 16),
                ApplicationsSection(postId: post.id),
              ],
              const SizedBox(height: 20),

              // Actions
              ..._actions(context, ref, canRequest),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, bool canRequest) {
    if (detail.canManage) {
      if (post.status == PostStatus.matched) {
        return const [
          StatusBanner(
            tone: BannerTone.success,
            icon: AppIcon(AppIcons.checkCircle, color: AppColors.greenSoftText),
            child: Text('Đã chốt kèo. Trận đã vào lịch đội.'),
          ),
        ];
      }
      if (post.status == PostStatus.closed) {
        return const [
          StatusBanner(tone: BannerTone.neutral, child: Text('Kèo đã đóng.')),
        ];
      }
      return [
        LimeButton(
          label: post.requestCount == 0
              ? 'Chưa có đội nhận kèo'
              : 'Xem & chọn đối (${post.requestCount} đội)',
          onPressed: post.requestCount == 0
              ? null
              : () => context.push(Routes.postCompare(post.team.id, post.id)),
          expand: true,
        ),
        const SizedBox(height: 10),
        SoftButton(
          label: 'Đóng kèo',
          color: AppColors.card,
          onPressed: () => _close(context, ref),
        ),
      ];
    }

    final mine = detail.myRequest;
    final finished =
        mine != null &&
        !mine.status.isPending &&
        mine.status != RequestStatus.accepted;
    if (mine != null && !(finished && canRequest)) {
      final pending = mine.status.isPending;
      return [
        StatusBanner(
          tone: pending
              ? BannerTone.waiting
              : mine.status == RequestStatus.accepted
              ? BannerTone.success
              : BannerTone.neutral,
          icon: pending
              ? const AppIcon(AppIcons.clock, color: AppColors.warnText)
              : null,
          child: Text(
            pending
                ? '${mine.teamName} đã gửi nhận kèo. Tự huỷ sau ${Fmt.remaining(mine.expiresAt.difference(DateTime.now()))} nếu không được trả lời.'
                : '${mine.teamName}: ${Labels.requestStatus(mine.status)}.',
          ),
        ),
        const SizedBox(height: 10),
        SoftButton(
          label: 'Xem yêu cầu',
          onPressed: () => context.push(Routes.request(mine.teamId, mine.id)),
        ),
        if (mine.status == RequestStatus.accepted) ...[
          const SizedBox(height: 10),
          LimeButton(
            label: 'Nhắn tin',
            onPressed: () =>
                openChatForRequest(context, ref, teamId: mine.teamId, requestId: mine.id),
            expand: true,
          ),
        ],
      ];
    }

    if (canRequest) {
      return [
        LimeButton(
          label: post.type == PostType.passPitch ? 'Nhận sân' : 'Nhận kèo',
          onPressed: () => context.push(Routes.postRequest(post.id)),
          expand: true,
        ),
      ];
    }
    if (post.type == PostType.recruit && post.status.isOpen) {
      final applied = detail.myApplicationStatus;
      if (applied != null) {
        return [
          StatusBanner(
            tone: applied == ApplicationStatus.accepted ? BannerTone.success : BannerTone.waiting,
            child: Text(applicationStatusLabel(applied)),
          ),
        ];
      }
      return [
        LimeButton(
          label: 'Ứng tuyển',
          onPressed: () => applyToPost(context, ref, post),
          expand: true,
        ),
      ];
    }
    if (!post.status.isOpen) {
      return const [
        StatusBanner(
          tone: BannerTone.neutral,
          child: Text('Kèo đã có đối hoặc đã đóng.'),
        ),
      ];
    }
    return const [];
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng kèo?'),
        content: const Text(
          'Kèo sẽ gỡ khỏi Bảng tin, các đội đang chờ được báo là kèo đã đóng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.card),
            child: const Text('Đóng kèo'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ok = await runAction(
      context,
      () => ref.read(postsRepositoryProvider).close(post.team.id, post.id),
      success: 'Đã đóng kèo',
    );
    if (ok) {
      ref.invalidate(postDetailProvider(post.id));
      ref.invalidate(feedProvider);
    }
  }
}

class _PitchRow extends StatelessWidget {
  const _PitchRow({required this.name, required this.area, this.lat, this.lng});
  final String name;
  final String area;
  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const AppIcon(AppIcons.pin, color: AppColors.lime, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                area,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: AppColors.lime,
          ),
          onPressed: () => _directions(context),
          child: const Text('Chỉ đường'),
        ),
      ],
    ),
  );

  Future<void> _directions(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': lat != null && lng != null ? '$lat,$lng' : '$name, $area',
    });
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showToast(context, 'Không mở được bản đồ', type: ToastType.error);
    }
  }
}
