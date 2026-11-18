import 'package:flutter/services.dart';
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
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/team_crest.dart';
import '../posts_providers.dart';
import 'application_widgets.dart';
import 'community_widgets.dart';

/// Màu nhãn theo loại kèo (như bản vẽ màn 1).
({Color bg, Color fg}) postTypeColors(PostType t) => switch (t) {
  PostTypeKnown(value: PostTypeValue.recruit) => (
    bg: AppColors.orangeSoft,
    fg: AppColors.orangeText,
  ),
  PostTypeKnown(value: PostTypeValue.passPitch) => (
    bg: AppColors.greenSoft,
    fg: AppColors.greenSoftText,
  ),
  _ => (bg: AppColors.primarySoft, fg: AppColors.primarySoftText),
};

class PostTypeBadge extends StatelessWidget {
  const PostTypeBadge(this.type, {super.key});
  final PostType type;

  @override
  Widget build(BuildContext context) {
    final c = postTypeColors(type);
    return Tag(Labels.postType(type), bg: c.bg, fg: c.fg);
  }
}

/// Tiền sân mỗi đội trả theo tỷ lệ (null khi không có giá hoặc không chia tiền).
({int win, int lose})? feeSplit(int? price, int? ratioWin, int? ratioLose) {
  if (price == null || price <= 0 || ratioWin == null || ratioLose == null) {
    return null;
  }
  final win = (price * ratioWin / 100).round();
  return (win: win, lose: price - win);
}

/// Các ô thông tin của kèo: thời gian, sân, trình độ, tỷ lệ / vị trí / giá.
List<(String, String)> postInfo(PostDto p, {bool short = false}) {
  final pitch = p.pitchName;
  return [
    ('Thời gian', Fmt.slot(p.startAt)),
    switch (p.type) {
      PostTypeKnown(value: PostTypeValue.recruit) => (
        'Cần',
        [
          if (p.playersNeeded != null) '${p.playersNeeded} người',
          ...p.positions.map((e) => Labels.position(e)!),
        ].join(', '),
      ),
      _ => ('Sân', pitch ?? 'Chưa có sân'),
    },
    ('Trình độ', short ? Labels.level(p.level) : Labels.levelLong(p.level)),
    switch (p.type) {
      PostTypeKnown(value: PostTypeValue.passPitch) => (
        'Giá nhượng',
        p.pitchPrice == null ? 'Thương lượng' : Fmt.money(p.pitchPrice!),
      ),
      PostTypeKnown(value: PostTypeValue.recruit) => ('Khu vực', p.area),
      _ => ('Tỷ lệ', Labels.ratio(p.ratioWin, p.ratioLose, p.deal) ?? '—'),
    },
  ];
}

/// Lưới 2 cột nền tối: nhãn nhỏ phía trên, giá trị đậm phía dưới.
class InfoGrid extends StatelessWidget {
  const InfoGrid(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    Widget cell((String, String) kv) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kv.$1,
          style: const TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
        const SizedBox(height: 2),
        Text(
          kv.$2,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cell(items[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < items.length
                      ? cell(items[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Đầu thẻ kèo: avatar khiên đội · tên · thời gian đăng + khu vực · nhãn loại.
class PostTeamHeader extends StatelessWidget {
  const PostTeamHeader({super.key, required this.post, this.onTeamTap});
  final PostDto post;

  /// Bấm vào đội (mở hồ sơ đội). Null = không bấm được.
  final VoidCallback? onTeamTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTeamTap,
    behavior: HitTestBehavior.opaque,
    child: Row(
      children: [
        TeamCrest(name: post.team.name, color: post.team.crestColor, width: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.team.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${Fmt.ago(post.createdAt)} · ${post.area}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
        PostTypeBadge(post.type),
      ],
    ),
  );
}

/// Thẻ kèo trên Bảng tin (màn 1).
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.canRequest});
  final PostDto post;

  /// Tôi quản lý một đội khác đội đăng kèo (hiện nút "Nhận kèo").
  final bool canRequest;

  bool get _requestable => post.type != PostType.recruit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() => context.push(Routes.post(post.id));
    final canManageComments = ref
        .watch(managedTeamsProvider)
        .any((team) => team.teamId == post.team.id);
    final isUpcoming = post.startAt.isAfter(DateTime.now()) && post.status.isOpen;

    return GestureDetector(
      onTap: open,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostTeamHeader(
              post: post,
              onTeamTap: () => context.push(Routes.teamProfile(post.team.id)),
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 10),
              CountdownPill(target: post.startAt),
            ],
            if (post.body != null) ...[
              const SizedBox(height: 12),
              Text(
                post.body!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textMain,
                ),
              ),
            ],
            if (post.media.isNotEmpty) ...[
              const SizedBox(height: 12),
              PostMediaStrip(media: post.media),
            ],
            const SizedBox(height: 12),
            InfoGrid(postInfo(post)),
            if (post.type == PostType.recruit && post.positions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in post.positions)
                    if (Labels.position(p) case final label?)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.greenSoftText,
                          ),
                        ),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            PostCommunityBar(
              postId: post.id,
              canManageComments: canManageComments,
              compact: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.requestCount > 0
                        ? '${post.requestCount} đội đã gửi nhận kèo'
                        : _requestable
                        ? 'Chưa có đội nhận'
                        : '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDim,
                    ),
                  ),
                ),
                if (_requestable && canRequest)
                  LimeButton(
                    label: post.type == PostType.passPitch ? 'Nhận sân' : 'Nhận kèo',
                    onPressed: () => context.push(Routes.postRequest(post.id)),
                    height: AppSizes.tapTarget,
                  )
                else if (post.type == PostType.recruit && !canManageComments)
                  LimeButton(
                    label: post.myApplicationStatus == null
                        ? 'Ứng tuyển'
                        : applicationStatusLabel(post.myApplicationStatus!),
                    onPressed: post.myApplicationStatus != null
                        ? null
                        : () async {
                            if (await applyToPost(context, ref, post)) ref.invalidate(feedProvider);
                          },
                    height: AppSizes.tapTarget,
                  )
                else
                  LinkButton('Xem chi tiết', onTap: open),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dải trạng thái màu (vàng: chờ, xanh: đã chốt, xám: khác) như màn 9, 13.
enum BannerTone { waiting, success, neutral }

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.tone,
    required this.child,
    this.icon,
  });
  final BannerTone tone;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      BannerTone.waiting => (AppColors.warnSoft, AppColors.warnText, null),
      BannerTone.success => (
        AppColors.greenSoft,
        AppColors.greenSoftText,
        null,
      ),
      BannerTone.neutral => (
        AppColors.surfaceHigh,
        AppColors.textMain,
        AppColors.line,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: border == null ? null : Border.all(color: border),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: 14, color: fg, height: 1.4),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút mềm toàn chiều ngang (nền mờ, chữ đậm).
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.lime;
    return Material(
      color: fg.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh thao tác ghim dưới cùng (ví dụ: màn 4, 13).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.surfaceCard,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Tiêu đề trang chi tiết: mũi tên quay lại + tiêu đề giữa + tuỳ chọn bên phải.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    this.title,
    this.backLabel = 'Bảng tin',
    this.trailing,
  });
  final String? title;
  final String backLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextButton.icon(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(Routes.feed),
              icon: const AppIcon(
                AppIcons.back,
                size: 24,
                color: AppColors.textMain,
              ),
              label: Text(
                backLabel,
                style: const TextStyle(fontSize: 16, color: AppColors.textMain),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(right: 8),
              ),
            ),
          ),
          if (title != null)
            Expanded(
              child: Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Hộp thoại nhập tỷ lệ đội thắng trả (%); đội thua trả phần còn lại. Trả null nếu huỷ.
Future<int?> showRatioDialog(
  BuildContext context, {
  required String title,
  required int initial,
}) async {
  final ctrl = TextEditingController(text: '$initial');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: const InputDecoration(
          labelText: 'Đội thắng trả (%)',
          helperText: 'Đội thua trả phần còn lại',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () {
            final n = int.tryParse(ctrl.text);
            if (n != null && n >= 0 && n <= 100) Navigator.pop(ctx, n);
          },
          child: const Text('Xong'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return v;
}

/// Ảnh đính kèm của kèo: một ảnh hiện to, nhiều ảnh cuộn ngang. Có trạng thái tải và lỗi.
class PostMediaStrip extends StatelessWidget {
  const PostMediaStrip({super.key, required this.media});
  final List<PostMediaDto> media;

  @override
  Widget build(BuildContext context) {
    final single = media.length == 1;
    return SizedBox(
      height: single ? 200 : 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: AspectRatio(
            aspectRatio: single ? 16 / 10 : 1,
            child: Image.network(
              media[i].url,
              fit: BoxFit.cover,
              semanticLabel: 'Ảnh kèo ${i + 1}',
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const ColoredBox(color: AppColors.surfaceHigh),
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surfaceHigh,
                child: Center(
                  child: AppIcon(
                    AppIcons.image,
                    size: 28,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
