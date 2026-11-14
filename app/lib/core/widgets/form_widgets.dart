import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'common.dart';

/// Đầu trang form: Huỷ · Tiêu đề · Lưu (như màn 20).
class FormHeader extends StatelessWidget {
  const FormHeader({super.key, required this.title, required this.saving, required this.onSave});
  final String title;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
    child: Row(
      children: [
        LinkButton('Huỷ', onTap: () => context.pop()),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        saving
            ? const SizedBox(
                width: 36,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : GestureDetector(
                onTap: onSave,
                child: const SizedBox(
                  height: AppSizes.tapTarget,
                  child: Center(
                    child: Text(
                      'Lưu',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    ),
  );
}

class FormCaption extends StatelessWidget {
  const FormCaption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, letterSpacing: 0.3),
    ),
  );
}

class FormGroup extends StatelessWidget {
  const FormGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.group),
    ),
    child: Column(
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          c,
        ],
      ],
    ),
  );
}

class FormTapRow extends StatelessWidget {
  const FormTapRow({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 16, color: AppColors.primary)),
        ],
      ),
    ),
  );
}
