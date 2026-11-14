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

/// Màu nhãn theo loại kèo (như bản vẽ màn 1).
({Color bg, Color fg}) postTypeColors(PostType t) => switch (t) {
  PostTypeKnown(value: PostTypeValue.recruit) => (
    bg: const Color(0xFFFDF0E6),
    fg: const Color(0xFFA04800),
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
  if (price == null || price <= 0 || ratioWin == null || ratioLose == null) return null;
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

/// Lưới 2 cột nền xám: nhãn nhỏ phía trên, giá trị đậm phía dưới.
class InfoGrid extends StatelessWidget {
  const InfoGrid(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    Widget cell((String, String) kv) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kv.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(kv.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
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
                Expanded(child: i + 1 < items.length ? cell(items[i + 1]) : const SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Đầu thẻ kèo: avatar đội · tên · thời gian đăng + khu vực · nhãn loại.
class PostTeamHeader extends StatelessWidget {
  const PostTeamHeader({super.key, required this.post});
  final PostDto post;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      TeamAvatar(name: post.team.name, color: post.team.crestColor),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.team.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${Fmt.ago(post.createdAt)} · ${post.area}',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      PostTypeBadge(post.type),
    ],
  );
}

/// Thẻ kèo trên Bảng tin (màn 1).
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.canRequest});
  final PostDto post;

  /// Tôi quản lý một đội khác đội đăng kèo (hiện nút "Nhận kèo").
  final bool canRequest;

  bool get _requestable => post.type != PostType.recruit;

  @override
  Widget build(BuildContext context) {
    void open() => context.push(Routes.post(post.id));
    return GestureDetector(
      onTap: open,
      behavior: HitTestBehavior.opaque,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostTeamHeader(post: post),
            if (post.body != null) ...[
              const SizedBox(height: 12),
              Text(post.body!, style: const TextStyle(fontSize: 16, height: 1.45)),
            ],
            const SizedBox(height: 12),
            InfoGrid(postInfo(post)),
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
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
                if (_requestable && canRequest)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    onPressed: () => context.push(Routes.postRequest(post.id)),
                    child: Text(post.type == PostType.passPitch ? 'Nhận sân' : 'Nhận kèo'),
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
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.tone, required this.child, this.icon});
  final BannerTone tone;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      BannerTone.waiting => (const Color(0xFFFFF6D6), const Color(0xFF7A5A00), null),
      BannerTone.success => (AppColors.greenSoft, AppColors.greenSoftText, null),
      BannerTone.neutral => (AppColors.background, AppColors.text, AppColors.border),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.group),
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

enum BannerTone { waiting, success, neutral }

/// Thanh nút cố định đáy màn (nền trắng mờ, viền trên).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      border: const Border(top: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 8), c],
      ],
    ),
  );
}

/// Nút viên thuốc phụ nền xám (Nhắn tin / Từ chối / Huỷ yêu cầu).
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      backgroundColor: AppColors.background,
      foregroundColor: color ?? AppColors.primary,
      minimumSize: const Size.fromHeight(46),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

/// Đầu trang chi tiết: nút quay lại + tiêu đề giữa.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.backLabel, this.title, this.trailing});
  final String backLabel;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 6),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.canPop() ? context.pop() : context.go(Routes.feed),
              icon: const AppIcon(AppIcons.back, size: 24, color: AppColors.primary),
              label: Text(backLabel, style: const TextStyle(fontSize: 17)),
              style: TextButton.styleFrom(padding: const EdgeInsets.only(right: 8)),
            ),
          ),
        ),
        if (title != null)
          Text(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: trailing ?? const SizedBox()),
        ),
      ],
    ),
  );
}
