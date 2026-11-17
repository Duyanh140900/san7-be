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
import '../../../core/widgets/team_crest.dart';
import '../../chat/presentation/chat_launcher.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'post_widgets.dart';
import 'community_widgets.dart';

/// Màn 14 · Chi tiết kèo. Bình luận, cảm xúc, ảnh/video có ở M5.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const DetailHeader(backLabel: 'Quay lại'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(postDetailProvider(postId).future),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
    final info = postInfo(post);
    if (split != null) info.add(('Thua trả', Fmt.money(split.lose)));
    if (post.deal case final d? when post.deal != PostDeal.split) {
      info.add(('Kèo', Labels.deal(d)!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostTeamHeader(
                post: post,
                onTeamTap: () => context.push(Routes.teamProfile(post.team.id)),
              ),
              if (post.body != null) ...[
                const SizedBox(height: 12),
                Text(
                  post.body!,
                  style: const TextStyle(fontSize: 16, height: 1.45),
                ),
              ],
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 12),
                PostMediaStrip(media: post.media),
              ],
              const SizedBox(height: 12),
              InfoGrid(info),
              if (post.pitchName != null) ...[
                const SizedBox(height: 12),
                _PitchRow(
                  name: post.pitchName!,
                  area: post.area,
                  lat: _num(detail, 'venueLat'),
                  lng: _num(detail, 'venueLng'),
                ),
              ],
              if (detail.requestTeams.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TeamAvatarStack(
                      teams: [
                        for (final t in detail.requestTeams)
                          (name: t.name, color: t.crestColor),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${post.requestCount} đội đã gửi nhận kèo',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              PostCommunityBar(
                postId: post.id,
                canManageComments: detail.canManage,
              ),
              const SizedBox(height: 16),
              ..._actions(context, ref, canRequest),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, bool canRequest) {
    // Đội đăng kèo
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
        FilledButton(
          onPressed: post.requestCount == 0
              ? null
              : () => context.push(Routes.postCompare(post.team.id, post.id)),
          child: Text(
            post.requestCount == 0
                ? 'Chưa có đội nhận kèo'
                : 'Xem & chọn đối (${post.requestCount} đội)',
          ),
        ),
        const SizedBox(height: 8),
        SoftButton(
          label: 'Đóng kèo',
          color: AppColors.red,
          onPressed: () => _close(context, ref),
        ),
      ];
    }

    // Đội tôi đã gửi yêu cầu
    final mine = detail.myRequest;
    // Yêu cầu cũ đã kết thúc mà kèo vẫn mở: cho gửi lại
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
        const SizedBox(height: 8),
        SoftButton(
          label: 'Xem yêu cầu',
          onPressed: () => context.push(Routes.request(mine.teamId, mine.id)),
        ),
        if (mine.status == RequestStatus.accepted) ...[
          const SizedBox(height: 8),
          SoftButton(
            label: 'Nhắn tin',
            onPressed: () =>
                openChatForRequest(context, ref, teamId: mine.teamId, requestId: mine.id),
          ),
        ],
      ];
    }

    if (canRequest) {
      return [
        FilledButton(
          onPressed: () => context.push(Routes.postRequest(post.id)),
          child: Text(
            post.type == PostType.passPitch ? 'Nhận sân' : 'Nhận kèo',
          ),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.divider),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.pitch,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const AppIcon(AppIcons.pin, color: Colors.white),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                area,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => _directions(context),
          child: const Text('Chỉ đường'),
        ),
      ],
    ),
  );

  /// Có toạ độ sân (`venueLat`/`venueLng`) thì chỉ đường theo toạ độ, không thì tìm theo tên sân.
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

/// Trường số backend thêm vào kèo (`venueLat`, `venueLng`), null khi chưa có.
double? _num(PostDetailDto detail, String key) {
  final v = detail.post.additionalProperties[key] ?? detail.additionalProperties[key];
  return v is num ? v.toDouble() : null;
}
