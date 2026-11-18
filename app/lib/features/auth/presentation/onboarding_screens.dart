export 'permissions_step.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/labels.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/form_field_row.dart';
import '../../../core/widgets/lime_button.dart';
import '../../../core/widgets/pills.dart';
import '../../team/data/team_repository.dart';
import '../data/auth_repository.dart';
import 'onboarding_scaffold.dart';

void _toast(BuildContext context, String message, {ToastType type = ToastType.error}) {
  showToast(context, message, type: type);
}

/// Nội dung cuộn được, phần [bottom] luôn nằm cuối màn khi nội dung ngắn.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.content, required this.bottom, this.top = 28});

  final List<Widget> content;
  final List<Widget> bottom;
  final double top;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(top: top, bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._spaced(content),
                const Spacer(),
                const SizedBox(height: 20),
                ..._spaced(bottom, gap: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> items, {double gap = 14}) => [
    for (var i = 0; i < items.length; i++) ...[if (i > 0) SizedBox(height: gap), items[i]],
  ];
}

/// Thêm lề 24 hai bên (hàng nút viên thuốc thì không, để cuộn tràn mép).
Widget _pad(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
  child: child,
);

// ─────────────────────────── Bước 1: Đăng nhập ───────────────────────────

class WelcomeStep extends ConsumerStatefulWidget {
  const WelcomeStep({super.key});

  @override
  ConsumerState<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends ConsumerState<WelcomeStep> {
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } on SignInCancelled {
      // Người dùng tự huỷ: không báo lỗi
    } catch (e) {
      // Mọi lỗi khác (cấu hình Google, mạng, API) đều phải hiện cho người dùng
      if (mounted) _toast(context, ApiError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 1,
      child: _StepBody(
        top: 32,
        content: [
          _pad(
            const Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BallMark(size: 40, spin: true),
                  SizedBox(width: 10),
                  Text('SÂN 7', style: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, fontSize: 28, color: AppColors.lime)),
                ],
              ),
            ),
          ),
          _pad(
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  text: 'CÁP KÈO.\nĐẶT SÂN.\n',
                  children: [TextSpan(text: 'VÀO TRẬN.', style: AppText.display(56, color: AppColors.lime))],
                ),
                style: AppText.display(56, height: 0.95),
              ),
            ),
          ),
          _pad(
            const Text(
              'Một app cho anh em đá sân 7. Vào nhanh bằng Google, không cần mật khẩu.',
              style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 6),
          _pad(
            LimeButton(
              label: 'Tiếp tục với Google',
              loading: _loading,
              onPressed: _loading ? null : _signIn,
            ),
          ),
          // Nút Apple chỉ có trên iOS, chưa có tài khoản Apple nên chưa đăng nhập được
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
            _pad(
              GhostButton(
                label: 'Tiếp tục với Apple',
                onPressed: () => _toast(context, 'Đăng nhập Apple sẽ có ở bản sau', type: ToastType.warning),
              ),
            ),
          _pad(
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.lock, size: 18, color: AppColors.textDim),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App chỉ lấy tên, email và ảnh đại diện từ Google. Không đăng bài thay bạn.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textDim),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        bottom: [
          _pad(
            const Text.rich(
              TextSpan(
                text: 'Tiếp tục là đồng ý với ',
                children: [
                  TextSpan(text: 'Điều khoản', style: TextStyle(color: AppColors.lime)),
                  TextSpan(text: ' và '),
                  TextSpan(text: 'Chính sách riêng tư', style: TextStyle(color: AppColors.lime)),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Bước 2: Hồ sơ cầu thủ ───────────────────────────

class ProfileStep extends ConsumerStatefulWidget {
  const ProfileStep({super.key});

  @override
  ConsumerState<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends ConsumerState<ProfileStep> {
  late final TextEditingController _name;
  late final TextEditingController _shirt;
  PositionValue? _position;
  String? _area;
  bool _saving = false;

  MeDto? get _me => switch (ref.read(authControllerProvider)) {
    AuthSignedIn(:final me) => me,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    final me = _me;
    _name = TextEditingController(text: me?.name ?? '');
    _shirt = TextEditingController(text: me?.shirtNumber?.toString() ?? '');
    _position = switch (me?.position) {
      PositionKnown(:final value) => value,
      _ => null,
    };
    _area = me?.area ?? Labels.areas.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _shirt.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return _toast(context, 'Nhập tên hiển thị');
    if (_position == null) return _toast(context, 'Chọn vị trí sở trường');
    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: name,
            position: _position!,
            shirtNumber: int.tryParse(_shirt.text),
            area: _area,
          );
      // Router tự chuyển sang bước 3 hoặc Bảng tin
      if (mounted && GoRouterState.of(context).matchedLocation == Routes.onboardingProfile) {
        context.go(Routes.onboardingTeam);
      }
    } on ApiError catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Quay lại bước đăng nhập để chọn tài khoản Google khác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ở lại')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (ok == true) await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return OnboardingScaffold(
      step: 2,
      onBack: _back,
      child: _StepBody(
        content: [
          _pad(Text('HỒ SƠ CẦU THỦ', style: AppText.display(36))),
          if (me != null) _pad(_GoogleProfileCard(me: me)),
          _pad(
            FormFieldRow(
              label: 'Tên hiển thị',
              controller: _name,
              textAlign: TextAlign.right,
              textCapitalization: TextCapitalization.words,
            ),
          ),
          _pad(const SectionLabel('Vị trí sở trường')),
          PillSelector<PositionValue>(
            options: [for (final p in Labels.positions) p.$1],
            selected: _position,
            labelOf: (v) => Labels.positions.firstWhere((p) => p.$1 == v).$2,
            onSelected: (v) => setState(() => _position = v),
          ),
          _pad(
            _ShirtStepper(
              controller: _shirt,
              onChanged: () => setState(() {}),
            ),
          ),
          _pad(const SectionLabel('Khu vực hay đá')),
          PillSelector<String>(
            options: Labels.areas,
            selected: _area,
            labelOf: (a) => a,
            onSelected: (a) => setState(() => _area = a),
          ),
        ],
        bottom: [
          _pad(
            LimeButton(label: 'Tiếp tục', loading: _saving, onPressed: _saving ? null : _submit),
          ),
        ],
      ),
    );
  }
}

class _GoogleProfileCard extends StatelessWidget {
  const _GoogleProfileCard({required this.me});
  final MeDto me;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.length > 1 ? parts[parts.length - 2] : parts.first;
    final last = parts.last;
    return parts.length > 1
        ? (first.characters.first + last.characters.first).toUpperCase()
        : first.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            foregroundImage: me.avatarUrl != null ? NetworkImage(me.avatarUrl!) : null,
            child: Text(
              initials(me.name),
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  me.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  me.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              'Từ Google',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.greenSoftText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Bước 3: Vào đội ───────────────────────────

enum _TeamMode { join, create }

class TeamStep extends ConsumerStatefulWidget {
  const TeamStep({super.key, this.addAnother = false});

  /// Mở từ màn Cá nhân để tạo/vào thêm đội: xong thì quay lại, không có "Để sau".
  final bool addAnother;

  @override
  ConsumerState<TeamStep> createState() => _TeamStepState();
}

class _TeamStepState extends ConsumerState<TeamStep> {
  _TeamMode _mode = _TeamMode.join;
  final _code = TextEditingController();
  final _teamName = TextEditingController();
  String _area = Labels.areas.first;
  TeamLevelValue _level = TeamLevelValue.tb;
  TeamInvitePreviewDto? _preview;
  String? _previewError;
  String? _pending;
  bool _busy = false;
  int _lookupSeq = 0;

  static final _codePattern = RegExp(r'^[A-Z0-9]{3}-?\d{4}$');

  @override
  void initState() {
    super.initState();
    final s = ref.read(authControllerProvider);
    if (s is AuthSignedIn && s.me.area != null) _area = s.me.area!;
  }

  @override
  void dispose() {
    _code.dispose();
    _teamName.dispose();
    super.dispose();
  }

  Future<void> _onCodeChanged(String raw) async {
    final code = raw.replaceAll(' ', '').toUpperCase();
    final seq = ++_lookupSeq;
    setState(() {
      _preview = null;
      _previewError = null;
    });
    if (!_codePattern.hasMatch(code)) return;
    try {
      final p = await ref.read(teamRepositoryProvider).previewInvite(code);
      if (mounted && seq == _lookupSeq) setState(() => _preview = p);
    } on ApiError catch (e) {
      if (mounted && seq == _lookupSeq) setState(() => _previewError = e.message);
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final teams = ref.read(teamRepositoryProvider);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_mode == _TeamMode.join) {
        final m = await teams.join(_code.text.replaceAll(' ', ''));
        if (m.status == MemberStatus.pending) {
          // Yêu cầu chờ đội trưởng duyệt: ở lại màn để báo trạng thái
          if (mounted) setState(() => _pending = m.teamName);
          return;
        }
      } else {
        final name = _teamName.text.trim();
        if (name.length < 2) {
          _toast(context, 'Nhập tên đội', type: ToastType.warning);
          return;
        }
        final t = await teams.create(name: name, area: _area, level: _level);
        if (mounted) _toast(context, 'Đã tạo ${t.name}. Mã mời: ${t.inviteCode}', type: ToastType.success);
      }
      if (widget.addAnother) {
        await auth.reloadMe();
        if (mounted && context.canPop()) context.pop();
      } else {
        // Sang bước 4 (quyền truy cập); bước đó tải lại hồ sơ rồi vào Bảng tin
        if (mounted) context.go(Routes.onboardingPermissions);
      }
    } on ApiError catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    await ref.read(authControllerProvider.notifier).skipTeamStep();
    if (!mounted) return;
    context.go(widget.addAnother ? Routes.feed : Routes.onboardingPermissions);
  }

  @override
  Widget build(BuildContext context) {
    final isJoin = _mode == _TeamMode.join;
    final pending = _pending;
    final canSubmit = !_busy && (isJoin ? _preview != null : _teamName.text.trim().length >= 2);
    final cta = isJoin ? (_preview != null ? 'Vào đội ${_preview!.name}' : 'Vào đội') : 'Tạo đội';

    return OnboardingScaffold(
      step: 3,
      onBack: () => widget.addAnother ? context.pop() : context.go(Routes.onboardingProfile),
      child: _StepBody(
        content: [
          _pad(Text('VÀO ĐỘI CỦA BẠN', style: AppText.display(36))),
          _pad(
            _OptionCard(
              selected: isJoin,
              icon: AppIcons.qr,
              iconBg: AppColors.primarySoft,
              iconColor: AppColors.primarySoftText,
              title: 'Tham gia đội',
              subtitle: 'Nhập mã mời hoặc quét QR',
              onTap: () => setState(() => _mode = _TeamMode.join),
            ),
          ),
          if (isJoin) ...[
            _pad(
              FormFieldRow(
                controller: _code,
                hint: 'Mã mời, ví dụ CG7-2486',
                style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: _onCodeChanged,
                trailing: GestureDetector(
                  onTap: () => _toast(context, 'Quét QR sẽ có ở bản sau'),
                  child: const Text(
                    'Quét QR',
                    style: TextStyle(fontSize: 15, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            if (_preview != null)
              _pad(
                _HintText(
                  '${_preview!.name} · ${_preview!.area} · '
                  '${Labels.level(_preview!.level)} · ${_preview!.memberCount} thành viên',
                ),
              ),
            if (_previewError != null) _pad(_HintText(_previewError!, color: AppColors.redBright)),
          ],
          if (pending != null) _pad(_PendingCard(teamName: pending)),
          _pad(
            _OptionCard(
              selected: !isJoin,
              icon: AppIcons.plus,
              iconBg: AppColors.greenSoft,
              iconColor: AppColors.greenSoftText,
              title: 'Tạo đội mới',
              subtitle: 'Bạn sẽ là đội trưởng',
              onTap: () => setState(() => _mode = _TeamMode.create),
            ),
          ),
          if (!isJoin) ...[
            _pad(
              FormFieldRow(
                controller: _teamName,
                hint: 'Tên đội, ví dụ FC Cầu Giấy',
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
                onChanged: (_) => setState(() {}),
              ),
            ),
            _pad(const SectionLabel('Khu vực')),
            PillSelector<String>(
              options: Labels.areas,
              selected: _area,
              labelOf: (a) => a,
              onSelected: (a) => setState(() => _area = a),
            ),
            _pad(const SectionLabel('Trình độ')),
            PillSelector<TeamLevelValue>(
              options: [for (final l in Labels.levels) l.$1],
              selected: _level,
              labelOf: (v) => Labels.levels.firstWhere((l) => l.$1 == v).$2,
              onSelected: (v) => setState(() => _level = v),
            ),
          ],
        ],
        bottom: [
          _pad(
            LimeButton(label: cta, loading: _busy, onPressed: canSubmit ? _submit : null),
          ),
          if (!widget.addAnother)
          _pad(
            GhostButton(
              label: _pending != null ? 'Xem Bảng tin trước' : 'Để sau, xem Bảng tin trước',
              height: 48,
              onPressed: _busy ? null : _skip,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final AppIcons icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            border: Border.all(color: selected ? AppColors.lime : AppColors.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: AppIcon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text, {this.color = AppColors.textSecondary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(text, style: TextStyle(fontSize: 13, color: color)),
  );
}

/// Màn 28: yêu cầu vào đội đã gửi, đang chờ đội trưởng duyệt.
class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.teamName});
  final String teamName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warnSoft,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: Border.all(color: AppColors.trophy.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppIcon(AppIcons.clock, color: AppColors.trophy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đã gửi yêu cầu, chờ duyệt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.trophy),
              ),
              const SizedBox(height: 4),
              Text(
                'Đội trưởng $teamName sẽ duyệt yêu cầu của bạn. Có kết quả app sẽ báo ngay.',
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textBody),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Số áo: nút − / + hai bên con số (màn 27). Vẫn dùng [controller] để lấy giá trị.
class _ShirtStepper extends StatelessWidget {
  const _ShirtStepper({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  void _step(int d) {
    final v = ((int.tryParse(controller.text) ?? 0) + d).clamp(0, 99);
    controller.text = v == 0 ? '' : '$v';
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final n = controller.text.isEmpty ? '—' : controller.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Số áo', style: TextStyle(fontSize: 15, color: AppColors.textDim)),
          ),
          const Spacer(),
          _StepBtn(label: '−', semantics: 'Giảm số áo', onTap: () => _step(-1)),
          SizedBox(
            width: 64,
            child: Text(n, textAlign: TextAlign.center, style: AppText.score(34)),
          ),
          _StepBtn(label: '+', semantics: 'Tăng số áo', onTap: () => _step(1)),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.label, required this.semantics, required this.onTap});
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppSizes.tapTarget,
        height: AppSizes.tapTarget,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.lineButton),
        ),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(fontSize: 22, color: AppColors.textMain)),
      ),
    ),
  );
}
