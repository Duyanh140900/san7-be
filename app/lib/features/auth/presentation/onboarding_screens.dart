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
import '../../../core/widgets/form_field_row.dart';
import '../../../core/widgets/pills.dart';
import '../../team/data/team_repository.dart';
import '../data/auth_repository.dart';
import 'onboarding_scaffold.dart';
import 'splash_screen.dart';

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
    final theme = Theme.of(context);
    return OnboardingScaffold(
      step: 1,
      child: _StepBody(
        top: 40,
        content: [
          _pad(const Align(alignment: Alignment.centerLeft, child: AppLogo())),
          _pad(
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Cáp kèo, đặt sân,\nquản lý đội.', style: theme.textTheme.displaySmall),
            ),
          ),
          _pad(
            const Text(
              'Một app cho anh em đá sân 7. Dùng tài khoản Google để vào nhanh, không cần mật khẩu.',
              style: TextStyle(fontSize: 17, height: 1.47, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 6),
          _pad(_GoogleButton(loading: _loading, onTap: _loading ? null : _signIn)),
          _pad(
            Opacity(
              opacity: 0.45,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.text,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text(
                  'Tiếp tục với Apple · bản iOS',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          _pad(
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.lock, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'App chỉ lấy tên, email và ảnh đại diện từ Google. Không đăng bài thay bạn.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
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
                text: 'Khi tiếp tục, bạn đồng ý với ',
                children: [
                  TextSpan(
                    text: 'Điều khoản',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: ' và '),
                  TextSpan(
                    text: 'Chính sách riêng tư',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.pillBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 12),
              const Text(
                'Tiếp tục với Google',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.text),
              ),
            ],
          ),
        ),
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
          _pad(Text('Hồ sơ cầu thủ', style: Theme.of(context).textTheme.headlineMedium)),
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
            FormFieldRow(
              label: 'Số áo',
              controller: _shirt,
              hint: '—',
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
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
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving ? const _ButtonSpinner() : const Text('Tiếp tục'),
            ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
  const TeamStep({super.key});

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
        if (mounted) {
          _toast(context, 'Đã gửi yêu cầu vào ${m.teamName}. Chờ đội trưởng duyệt.', type: ToastType.success);
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
      await auth.reloadMe(); // có đội → router chuyển sang Bảng tin
    } on ApiError catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    await ref.read(authControllerProvider.notifier).skipTeamStep();
    if (mounted) context.go(Routes.feed);
  }

  @override
  Widget build(BuildContext context) {
    final isJoin = _mode == _TeamMode.join;
    final canSubmit = !_busy && (isJoin ? _preview != null : _teamName.text.trim().length >= 2);
    final cta = isJoin ? (_preview != null ? 'Vào đội ${_preview!.name}' : 'Vào đội') : 'Tạo đội';

    return OnboardingScaffold(
      step: 3,
      onBack: () => context.go(Routes.onboardingProfile),
      child: _StepBody(
        content: [
          _pad(Text('Vào đội của bạn', style: Theme.of(context).textTheme.headlineMedium)),
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
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              child: _busy
                  ? const _ButtonSpinner()
                  : Text(cta, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          _pad(
            SizedBox(
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  textStyle: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onPressed: _busy ? null : _skip,
                child: const Text('Để sau, xem Bảng tin trước'),
              ),
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
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

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 22,
    height: 22,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}
