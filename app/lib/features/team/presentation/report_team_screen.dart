import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/team_crest.dart';
import '../../matches/matches_providers.dart';
import '../data/team_repository.dart';

class _ReportReason {
  const _ReportReason(this.label, this.note);
  final String label;
  final String note;
}

const _reasons = <_ReportReason>[
  _ReportReason('Bùng kèo không báo', 'Không đến sân, không nhắn trước'),
  _ReportReason('Đến muộn quá 30 phút', 'Làm mất giờ sân đã đặt'),
  _ReportReason('Không trả tiền sân', 'Không chuyển phần tiền theo kèo'),
  _ReportReason('Đá thô bạo, chơi xấu', 'Cố tình gây chấn thương'),
  _ReportReason('Lời lẽ xúc phạm', 'Trên sân hoặc trong tin nhắn'),
  _ReportReason('Khác', 'Mô tả ở bên dưới'),
];

/// Màn 38 · Báo cáo / chặn đội theo bản vẽ Floodlight Night.
class ReportTeamScreen extends ConsumerStatefulWidget {
  const ReportTeamScreen({
    super.key,
    required this.teamId,
    required this.targetTeamId,
    this.matchId,
  });

  final String teamId;
  final String targetTeamId;
  final String? matchId;

  @override
  ConsumerState<ReportTeamScreen> createState() => _ReportTeamScreenState();
}

class _ReportTeamScreenState extends ConsumerState<ReportTeamScreen> {
  int _selectedReason = -1;
  final _descCtrl = TextEditingController();
  bool _block = false;
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String targetTeamName) async {
    if (_selectedReason < 0) return;
    setState(() => _submitting = true);
    try {
      final repo = ref.read(teamRepositoryProvider);
      await repo.reportTeam(
        widget.teamId,
        CreateTeamReportDto(
          reportedTeamId: widget.targetTeamId,
          matchId: widget.matchId,
          reason: _reasons[_selectedReason].label,
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        ),
      );
      if (_block) {
        await repo.blockTeam(widget.teamId, widget.targetTeamId);
      }
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        AppToast.error(ApiError.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProfile = ref.watch(teamProfileProvider(widget.targetTeamId));
    final targetName = teamProfile.value?.team.name ?? 'Đội đối thủ';
    final targetCrest = teamProfile.value?.team.crestColor;

    if (_sent) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: AppIcon(AppIcons.checkCircle, size: 48, color: AppColors.lime),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ĐÃ NHẬN BÁO CÁO',
                  style: AppText.display(28),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ban quản trị sẽ xem trong 24 giờ. Nếu đúng, điểm uy tín của đội bị trừ và kèo của họ ít được gợi ý hơn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.5),
                ),
                if (_block) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.card.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Đã chặn $targetName',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.card,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: LimeButton(
                    label: 'Về Bảng tin',
                    onPressed: () => context.go(Routes.feed),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Báo cáo đội'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                children: [
                  // Banner đội bị báo cáo
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0D10),
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(color: AppColors.card.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        TeamCrest(name: targetName, color: targetCrest ?? '#2F7BFF', width: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                targetName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Báo cáo được giữ kín, đội bị báo không biết ai gửi',
                                style: TextStyle(fontSize: 12, color: AppColors.textDim),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lý do báo cáo
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHUYỆN GÌ ĐÃ XẢY RA?'.toUpperCase(),
                          style: AppText.display(14).copyWith(color: AppColors.textDim),
                        ),
                        const SizedBox(height: 12),
                        for (int i = 0; i < _reasons.length; i++) ...[
                          _ReasonRadioTile(
                            reason: _reasons[i],
                            selected: _selectedReason == i,
                            onTap: () => setState(() => _selectedReason = i),
                          ),
                          if (i < _reasons.length - 1)
                            const Divider(height: 1, color: AppColors.line),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Chi tiết mô tả
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MÔ TẢ CHI TIẾT'.toUpperCase(),
                          style: AppText.display(14).copyWith(color: AppColors.textDim),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 14, color: AppColors.textMain),
                          decoration: InputDecoration(
                            hintText: 'Kể ngắn gọn: giờ hẹn, chuyện xảy ra, ai liên quan…',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textDim),
                            filled: true,
                            fillColor: AppColors.surfaceHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                              borderSide: const BorderSide(color: AppColors.lineStrong),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                              borderSide: const BorderSide(color: AppColors.lineStrong),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.button),
                              borderSide: const BorderSide(color: AppColors.lime),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Switch Chặn đội này
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chặn đội này',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMain,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Không thấy kèo, tin nhắn của nhau nữa',
                                style: TextStyle(fontSize: 12, color: AppColors.textDim),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _block,
                          activeTrackColor: AppColors.card,
                          activeThumbColor: AppColors.textMain,
                          onChanged: (v) => setState(() => _block = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.night],
                  stops: [0.0, 0.3],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: LimeButton(
                  label: _selectedReason < 0
                      ? 'Chọn lý do để gửi'
                      : (_block ? 'Gửi báo cáo & chặn' : 'Gửi báo cáo'),
                  loading: _submitting,
                  onPressed: _selectedReason < 0 || _submitting
                      ? null
                      : () => _submit(targetName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRadioTile extends StatelessWidget {
  const _ReasonRadioTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final _ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.button),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.lime : AppColors.lineStrong,
                width: 2,
              ),
              color: selected ? AppColors.lime : Colors.transparent,
            ),
            child: selected
                ? const Center(
                    child: Icon(Icons.circle, size: 8, color: AppColors.ink),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.lime : AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason.note,
                  style: const TextStyle(fontSize: 12, color: AppColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
