import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/format.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/team_crest.dart';
import '../data/posts_repository.dart';
import '../posts_providers.dart';
import 'post_widgets.dart';

/// Màn 13 · Gửi nhận kèo.
class SendRequestScreen extends ConsumerWidget {
  const SendRequestScreen({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postDetailProvider(postId));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: post,
          onRetry: () => ref.invalidate(postDetailProvider(postId)),
          data: (d) => _Form(post: d.post),
        ),
      ),
    );
  }
}

enum _RatioChoice { agree, half, custom }

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.post});
  final PostDto post;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  String? _teamId;
  int _people = 9;
  _RatioChoice _ratio = _RatioChoice.agree;
  int _customWin = 50;
  final _message = TextEditingController();
  bool _sending = false;

  PostDto get post => widget.post;

  bool get _hasRatio =>
      post.type == PostType.findOpponent &&
      post.deal == PostDeal.split &&
      post.ratioWin != null &&
      post.ratioLose != null;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  int? get _proposedWin => switch (_ratio) {
    _RatioChoice.agree => null,
    _RatioChoice.half => 50,
    _RatioChoice.custom => _customWin,
  };

  String get _ratioNote {
    final win = _proposedWin ?? post.ratioWin!;
    final split = feeSplit(post.pitchPrice, win, 100 - win);
    final money = split == null
        ? ''
        : ' Đội thắng trả ${Fmt.money(split.win)}, đội thua trả ${Fmt.money(split.lose)}.';
    return switch (_ratio) {
      _RatioChoice.agree => 'Đồng ý tỷ lệ của kèo.$money',
      _ => 'Gửi đề xuất $win – ${100 - win}.$money Đội đăng kèo sẽ duyệt.',
    };
  }

  Future<void> _pickCustom() async {
    final ctrl = TextEditingController(text: '$_customWin');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đề xuất tỷ lệ'),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
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
    if (v != null) {
      setState(() {
        _customWin = v;
        _ratio = _RatioChoice.custom;
      });
    }
  }

  Future<void> _send(String teamId) async {
    setState(() => _sending = true);
    final win = _hasRatio ? _proposedWin : null;
    MyRequestDto? sent;
    final ok = await runAction(
      context,
      () async => sent = await ref
          .read(postsRepositoryProvider)
          .send(
            teamId,
            post.id,
            SendRequestDto(
              peopleCount: _people,
              ratioWin: win,
              ratioLose: win == null ? null : 100 - win,
              message: _message.text.trim().isEmpty ? null : _message.text.trim(),
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok && sent != null) {
      ref.invalidate(postDetailProvider(post.id));
      ref.invalidate(feedProvider);
      context.pushReplacement(Routes.request(sent!.teamId, sent!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = [
      for (final t in ref.watch(managedTeamsProvider))
        if (t.teamId != post.team.id) t,
    ];
    final teamId = teams.any((t) => t.teamId == _teamId) ? _teamId : teams.firstOrNull?.teamId;
    final isPass = post.type == PostType.passPitch;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              LinkButton('Huỷ', onTap: () => context.pop()),
              Expanded(
                child: Text(
                  isPass ? 'Nhận sân' : 'Nhận kèo',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TeamAvatar(name: post.team.name, color: post.team.crestColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kèo của ${post.team.name}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  post.area,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InfoGrid(postInfo(post, short: true)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FormCaption(isPass ? 'Đội nhận sân' : 'Đá với đội'),
              if (teams.isEmpty)
                const AppCard(
                  child: Text(
                    'Bạn cần là đội trưởng hoặc phó của một đội khác để nhận kèo.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                FormGroup(
                  children: [
                    for (final t in teams)
                      _TeamRadio(
                        team: t,
                        selected: t.teamId == teamId,
                        sameLevel: t.level == post.level,
                        onTap: () => setState(() => _teamId = t.teamId),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              const FormCaption('Số người dự kiến'),
              FormGroup(
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Số người đến sân', style: TextStyle(fontSize: 16)),
                        ),
                        _StepButton(
                          label: '−',
                          semantic: 'Bớt',
                          onTap: _people > 5 ? () => setState(() => _people--) : null,
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$_people',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                          ),
                        ),
                        _StepButton(
                          label: '+',
                          semantic: 'Thêm',
                          onTap: _people < 20 ? () => setState(() => _people++) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasRatio) ...[
                const SizedBox(height: 20),
                const FormCaption('Tỷ lệ chia tiền sân'),
                SizedBox(
                  height: AppSizes.tapTarget,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Choice(
                        label: 'Đồng ý ${post.ratioWin} – ${post.ratioLose}',
                        selected: _ratio == _RatioChoice.agree,
                        onTap: () => setState(() => _ratio = _RatioChoice.agree),
                      ),
                      if (post.ratioWin != 50)
                        _Choice(
                          label: 'Đề xuất 50 – 50',
                          selected: _ratio == _RatioChoice.half,
                          onTap: () => setState(() => _ratio = _RatioChoice.half),
                        ),
                      _Choice(
                        label: _ratio == _RatioChoice.custom
                            ? 'Đề xuất $_customWin – ${100 - _customWin}'
                            : 'Đề xuất khác',
                        selected: _ratio == _RatioChoice.custom,
                        onTap: _pickCustom,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    _ratioNote,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const FormCaption('Lời nhắn'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.group),
                ),
                child: TextField(
                  controller: _message,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 16, height: 1.45),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Ví dụ: Bên mình 9 người, đến đúng giờ. Mặc áo xanh.',
                  ),
                ),
              ),
            ],
          ),
        ),
        BottomActionBar(
          children: [
            FilledButton(
              onPressed: teamId == null || _sending ? null : () => _send(teamId),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isPass ? 'Gửi nhận sân' : 'Gửi nhận kèo'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TeamRadio extends StatelessWidget {
  const _TeamRadio({
    required this.team,
    required this.selected,
    required this.sameLevel,
    required this.onTap,
  });
  final MyTeamDto team;
  final bool selected;
  final bool sameLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.pillBorder,
                  width: selected ? 7 : 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                team.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              sameLevel ? 'Cùng trình độ' : Labels.level(team.level),
              style: TextStyle(
                fontSize: 13,
                fontWeight: sameLevel ? FontWeight.w600 : FontWeight.w400,
                color: sameLevel ? AppColors.greenSoftText : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.semantic, required this.onTap});
  final String label;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantic,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: AppColors.background, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            color: onTap == null ? AppColors.pillBorder : AppColors.primary,
          ),
        ),
      ),
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.pillBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primarySoftText : AppColors.text,
            ),
          ),
        ),
      ),
    ),
  );
}
