import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/lime_button.dart';
import 'onboarding_scaffold.dart';

enum _Perm { idle, granted, denied }

/// Màn 37 · Bước 4: xin quyền vị trí và thông báo.
class PermissionsStep extends ConsumerStatefulWidget {
  const PermissionsStep({super.key});

  @override
  ConsumerState<PermissionsStep> createState() => _PermissionsStepState();
}

class _PermissionsStepState extends ConsumerState<PermissionsStep> {
  _Perm _loc = _Perm.idle;
  // Chưa có gói thông báo đẩy (FCM) nên "Thông báo" mới là lựa chọn trong app,
  // quyền hệ thống sẽ xin khi có gói đó.
  _Perm _noti = _Perm.idle;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _readLocation();
  }

  Future<void> _readLocation() async {
    try {
      final p = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _loc = switch (p) {
          LocationPermission.always || LocationPermission.whileInUse => _Perm.granted,
          LocationPermission.deniedForever => _Perm.denied,
          _ => _Perm.idle,
        };
      });
    } catch (_) {}
  }

  Future<void> _askLocation() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (!mounted) return;
      setState(() {
        _loc = (p == LocationPermission.always || p == LocationPermission.whileInUse)
            ? _Perm.granted
            : _Perm.denied;
      });
    } catch (_) {
      if (mounted) setState(() => _loc = _Perm.denied);
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).reloadMe();
    } catch (_) {
      // Vào Bảng tin bằng hồ sơ đã có
    }
    if (mounted) context.go(Routes.feed);
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _loc == _Perm.granted && _noti == _Perm.granted;
    return OnboardingScaffold(
      step: 4,
      onBack: _busy ? null : () => context.go(Routes.onboardingTeam),
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                28,
                AppSizes.screenPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'ĐỂ APP TÌM KÈO\n',
                      children: [
                        TextSpan(text: 'GIÚP BẠN', style: AppText.display(36, color: AppColors.lime)),
                      ],
                    ),
                    style: AppText.display(36),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Hai quyền dưới đây giúp gợi ý sân, kèo gần bạn và nhắc lịch đá. Bạn đổi lại được trong Cài đặt bất cứ lúc nào.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  _PermCard(
                    icon: AppIcons.pin,
                    title: 'Vị trí',
                    body: 'Sân trống & kèo trong bán kính 5 km, chỉ đường tới sân',
                    state: _loc,
                    onAllow: _askLocation,
                    deniedHint: 'Đã từ chối. Bật lại trong Cài đặt điện thoại.',
                  ),
                  const SizedBox(height: 12),
                  _PermCard(
                    icon: AppIcons.bell,
                    title: 'Thông báo',
                    body: 'Có đội nhận kèo, nhắc điểm danh, nhắc đóng quỹ, kết quả trận',
                    state: _noti,
                    onAllow: () => setState(() => _noti = _Perm.granted),
                    deniedHint: '',
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(AppIcons.lock, size: 18, color: AppColors.textDim),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Vị trí chỉ dùng khi bạn mở app, không chia sẻ cho đội khác. Đội đối chỉ thấy khu vực, không thấy vị trí chính xác.',
                          style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textDim),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(height: 20),
                  LimeButton(
                    label: allDone ? 'Vào sân' : 'Cho phép tất cả',
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : allDone
                        ? _finish
                        : () async {
                            if (_loc != _Perm.granted) await _askLocation();
                            if (mounted) setState(() => _noti = _Perm.granted);
                          },
                  ),
                  const SizedBox(height: 10),
                  GhostButton(label: 'Để sau', height: 48, onPressed: _busy ? null : _finish),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.state,
    required this.onAllow,
    required this.deniedHint,
  });

  final AppIcons icon;
  final String title;
  final String body;
  final _Perm state;
  final VoidCallback onAllow;
  final String deniedHint;

  @override
  Widget build(BuildContext context) {
    final granted = state == _Perm.granted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: granted ? AppColors.lime : AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, color: AppColors.lime),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.textMuted),
                ),
                if (state == _Perm.denied && deniedHint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(deniedHint, style: const TextStyle(fontSize: 13, color: AppColors.card)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (granted)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: AppIcon(AppIcons.checkCircle, color: AppColors.lime),
            )
          else
            GestureDetector(
              onTap: onAllow,
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
                alignment: Alignment.center,
                child: const Text(
                  'Bật',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.lime),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
