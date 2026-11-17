import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../api/exports.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/labels.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/form_field_row.dart';
import '../../../core/widgets/pills.dart';
import '../../posts/presentation/post_widgets.dart';

/// Sửa hồ sơ: tên, vị trí, số áo, khu vực (PATCH /v1/me). Ảnh đại diện chờ backend hỗ trợ avatarUrl.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _shirt;
  PositionValue? _position;
  String? _area;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    final me = auth is AuthSignedIn ? auth.me : null;
    _name = TextEditingController(text: me?.name ?? '');
    _shirt = TextEditingController(text: me?.shirtNumber?.toString() ?? '');
    _position = switch (me?.position) {
      PositionKnown(:final value) => value,
      _ => null,
    };
    _area = me?.area;
  }

  @override
  void dispose() {
    _name.dispose();
    _shirt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showToast(context, 'Nhập tên hiển thị', type: ToastType.warning);
    if (_position == null) {
      return showToast(context, 'Chọn vị trí sở trường', type: ToastType.warning);
    }
    setState(() => _saving = true);
    final ok = await runAction(
      context,
      () => ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: name,
            position: _position!,
            shirtNumber: int.tryParse(_shirt.text),
            area: _area,
          ),
      success: 'Đã lưu hồ sơ',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          DetailHeader(
            backLabel: 'Cá nhân',
            title: 'Sửa hồ sơ',
            trailing: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                FormFieldRow(
                  label: 'Tên hiển thị',
                  controller: _name,
                  textAlign: TextAlign.right,
                  textCapitalization: TextCapitalization.words,
                ),
                const SectionLabel('Vị trí sở trường'),
                PillSelector<PositionValue>(
                  options: [for (final p in Labels.positions) p.$1],
                  selected: _position,
                  labelOf: (v) => Labels.positions.firstWhere((p) => p.$1 == v).$2,
                  onSelected: (v) => setState(() => _position = v),
                  padding: 0,
                ),
                const SizedBox(height: 16),
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
                const SectionLabel('Khu vực hay đá'),
                PillSelector<String>(
                  options: Labels.areas,
                  selected: _area,
                  labelOf: (a) => a,
                  onSelected: (a) => setState(() => _area = a),
                  padding: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
