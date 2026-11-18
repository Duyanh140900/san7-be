import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/widgets/app_toast.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/pitch_art.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/pitches_repository.dart';
import '../pitches_providers.dart';
import 'pitch_widgets.dart';

/// Màn 32 · Đánh giá sân MỚI (Floodlight Night v2).
class PitchReviewsScreen extends ConsumerStatefulWidget {
  const PitchReviewsScreen({super.key, required this.pitchId, this.bookingId});
  final String pitchId;
  final String? bookingId;

  @override
  ConsumerState<PitchReviewsScreen> createState() => _PitchReviewsScreenState();
}

class _PitchReviewsScreenState extends ConsumerState<PitchReviewsScreen> {
  int _stars = 5;
  final Set<String> _selectedTags = {'Cỏ đẹp', 'Đèn sáng'};
  final _commentCtrl = TextEditingController();
  bool _sending = false;
  PitchReviewDto? _myReview;

  static const _tagOptions = [
    'Cỏ đẹp',
    'Đèn sáng',
    'Đúng giờ',
    'Giá hợp lý',
    'Có nước lạnh',
    'Gửi xe rộng',
  ];

  static const _starWords = [
    'Chạm để chấm',
    'Tệ',
    'Chưa ổn',
    'Tạm được',
    'Tốt',
    'Tuyệt vời',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_stars <= 0 || _sending) return;
    setState(() => _sending = true);

    try {
      final res = await ref.read(pitchesRepositoryProvider).createReview(
        widget.pitchId,
        stars: _stars,
        turf: _stars == 5 ? 5 : (_stars >= 4 ? 4.5 : 3.5),
        lighting: _stars == 5 ? 5 : 4.5,
        lockerRoom: 4.5,
        ownerPrice: 4.5,
        tags: _selectedTags.toList(),
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
        bookingId: widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _myReview = res;
      });
      showToast(context, 'Đã gửi đánh giá · cảm ơn bạn', type: ToastType.success);
      ref.invalidate(pitchReviewsProvider(widget.pitchId));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(context, 'Không gửi được đánh giá, thử lại sau', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(pitchReviewsProvider(widget.pitchId));
    final reviews = reviewsAsync.value ?? const <PitchReviewDto>[];

    final avg = averageStars(reviews) ?? 4.8;
    final total = reviews.isNotEmpty ? reviews.length : 230;

    return Scaffold(
      backgroundColor: AppColors.night,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeaderCover(
              pitchId: widget.pitchId,
              onBack: () => context.pop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Thẻ điểm trung bình & phân bố sao
                _RatingOverview(
                  avg: avg,
                  total: total + (_myReview != null ? 1 : 0),
                  reviews: reviews,
                ),
                const SizedBox(height: 12),

                // Lưới 4 tiêu chí (2x2)
                const _CriteriaGrid(),
                const SizedBox(height: 16),

                // Khối form chấm điểm
                _ReviewForm(
                  stars: _stars,
                  starWord: _starWords[_stars],
                  tagOptions: _tagOptions,
                  selectedTags: _selectedTags,
                  controller: _commentCtrl,
                  sending: _sending,
                  sent: _myReview != null,
                  onSelectStar: (n) => setState(() => _stars = n),
                  onToggleTag: (t) => setState(() {
                    if (_selectedTags.contains(t)) {
                      _selectedTags.remove(t);
                    } else {
                      _selectedTags.add(t);
                    }
                  }),
                  onSubmit: _submitReview,
                ),
                const SizedBox(height: 20),

                // Danh sách đánh giá
                const V2Label('ĐÁNH GIÁ MỚI NHẤT'),
                const SizedBox(height: 10),

                if (_myReview != null) ...[
                  _ReviewItem(review: _myReview!, isMine: true),
                  const SizedBox(height: 10),
                ],

                if (reviews.isEmpty && _myReview == null) ...[
                  // Đánh giá mẫu nếu chưa có dữ liệu từ backend
                  const _MockReview(
                    name: 'Tiến Linh',
                    team: 'FC Mỹ Đình',
                    time: '2 ngày trước',
                    stars: 5,
                    comment: 'Cỏ mới, đèn sáng đều cả 4 góc. Chủ sân giữ giờ chuẩn, có nước lạnh bán tại chỗ.',
                    tags: ['Cỏ đẹp', 'Đèn sáng', 'Đúng giờ'],
                  ),
                  const SizedBox(height: 10),
                  const _MockReview(
                    name: 'Quang Tuấn',
                    team: 'FC Cầu Giấy',
                    time: '5 ngày trước',
                    stars: 5,
                    comment: 'Sân rộng, bãi đỗ xe ô tô thoải mái. Sẽ quay lại đặt tiếp.',
                    tags: ['Gửi xe rộng', 'Giá hợp lý'],
                  ),
                ] else
                  for (final r in reviews) ...[
                    _ReviewItem(review: r),
                    const SizedBox(height: 10),
                  ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCover extends StatelessWidget {
  const _HeaderCover({required this.pitchId, required this.onBack});
  final String pitchId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const PitchArt(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.night.withValues(alpha: 0.4),
                  Colors.transparent,
                  AppColors.night,
                ],
              ),
            ),
          ),
          Positioned(
            top: top + 8,
            left: 16,
            child: GlassButton(
              icon: AppIcons.back,
              label: 'Quay lại chi tiết sân',
              onTap: onBack,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ĐÁNH GIÁ SÂN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'HÀ ĐỒNG ARENA',
                  style: AppText.display(32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingOverview extends StatelessWidget {
  const _RatingOverview({
    required this.avg,
    required this.total,
    required this.reviews,
  });
  final double avg;
  final int total;
  final List<PitchReviewDto> reviews;

  @override
  Widget build(BuildContext context) => V2Card(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              avg.toStringAsFixed(1).replaceAll('.', ','),
              style: AppText.score(52, color: AppColors.trophy),
            ),
            const Text(
              '★★★★★',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 2,
                color: AppColors.trophy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$total đánh giá',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              for (var star = 5; star >= 1; star--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 12,
                        child: Text(
                          '$star',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDim),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            height: 7,
                            color: AppColors.surfaceHigh,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: star == 5 ? 0.82 : (star == 4 ? 0.12 : (star == 3 ? 0.04 : 0.01)),
                              child: Container(color: AppColors.trophy),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CriteriaGrid extends StatelessWidget {
  const _CriteriaGrid();

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 2.8,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: const [
      _CriteriaBox(score: '4,9', label: 'Mặt cỏ', scoreColor: AppColors.lime),
      _CriteriaBox(score: '4,8', label: 'Đèn chiếu sáng', scoreColor: AppColors.lime),
      _CriteriaBox(score: '4,5', label: 'Phòng thay đồ', scoreColor: AppColors.trophy),
      _CriteriaBox(score: '4,7', label: 'Chủ sân, giá cả', scoreColor: AppColors.lime),
    ],
  );
}

class _CriteriaBox extends StatelessWidget {
  const _CriteriaBox({required this.score, required this.label, required this.scoreColor});
  final String score;
  final String label;
  final Color scoreColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(score, style: AppText.score(22, color: scoreColor)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.stars,
    required this.starWord,
    required this.tagOptions,
    required this.selectedTags,
    required this.controller,
    required this.sending,
    required this.sent,
    required this.onSelectStar,
    required this.onToggleTag,
    required this.onSubmit,
  });
  final int stars;
  final String starWord;
  final List<String> tagOptions;
  final Set<String> selectedTags;
  final TextEditingController controller;
  final bool sending;
  final bool sent;
  final ValueChanged<int> onSelectStar;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => V2Card(
    borderColor: AppColors.lime.withValues(alpha: 0.25),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const V2Label('ĐÁNH GIÁ CỦA BẠN', color: AppColors.lime),
            Text(
              starWord,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.trophy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 5 ngôi sao
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              GestureDetector(
                onTap: () => onSelectStar(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.star,
                    size: 38,
                    color: i <= stars ? AppColors.trophy : AppColors.surfaceHigh,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // Thẻ đánh giá nhanh
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in tagOptions) ...[
              GestureDetector(
                onTap: () => onToggleTag(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selectedTags.contains(t) ? AppColors.lime : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedTags.contains(t) ? AppColors.lime : AppColors.line,
                    ),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selectedTags.contains(t) ? AppColors.ink : AppColors.textMain,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Nhận xét chi tiết
        TextField(
          controller: controller,
          maxLines: 2,
          style: const TextStyle(fontSize: 14, color: AppColors.textMain),
          decoration: InputDecoration(
            hintText: 'Cỏ, đèn, chỗ gửi xe, chủ sân thế nào?',
            hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textDim),
            filled: true,
            fillColor: AppColors.surfaceHigh,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.lime),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LimeButton(
          label: sent
              ? 'Đã gửi đánh giá · cảm ơn bạn'
              : (stars > 0 ? 'Gửi đánh giá $stars sao' : 'Chọn số sao để gửi'),
          loading: sending,
          onPressed: sent || stars <= 0 ? null : onSubmit,
        ),
      ],
    ),
  );
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review, this.isMine = false});
  final PitchReviewDto review;
  final bool isMine;

  @override
  Widget build(BuildContext context) => V2Card(
    padding: const EdgeInsets.all(14),
    borderColor: isMine ? AppColors.lime.withValues(alpha: 0.3) : AppColors.line,
    color: isMine ? AppColors.lime.withValues(alpha: 0.06) : AppColors.surfaceCard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const TeamAvatar(name: 'FC', color: '#2F7BFF', size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMine ? 'Bạn' : 'Người chơi',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                  ),
                  Text(
                    Fmt.time(review.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '★ ${review.stars}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.trophy),
            ),
          ],
        ),
        if (review.comment != null && (review.comment ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            review.comment!,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFFDCE7DF)),
          ),
        ],
        if (review.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in review.tags)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    t,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _MockReview extends StatelessWidget {
  const _MockReview({
    required this.name,
    required this.team,
    required this.time,
    required this.stars,
    required this.comment,
    required this.tags,
  });
  final String name;
  final String team;
  final String time;
  final int stars;
  final String comment;
  final List<String> tags;

  @override
  Widget build(BuildContext context) => V2Card(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TeamAvatar(name: team, color: '#E5383B', size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                  ),
                  Text(
                    '$time · $team',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '★' * stars,
              style: const TextStyle(fontSize: 13, color: AppColors.trophy, letterSpacing: 1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          comment,
          style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFFDCE7DF)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  t,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
