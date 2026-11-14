import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Ô nhập nền trắng bo 14, nhãn bên trái, giá trị bên phải (như bản vẽ).
class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.trailing,
    this.style,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  final String? label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final Widget? trailing;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.group),
      ),
      child: Row(
        children: [
          if (label != null) ...[
            Text(label!, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textAlign: textAlign,
              onChanged: onChanged,
              textCapitalization: textCapitalization,
              style: (style ?? const TextStyle()).copyWith(fontSize: 17, color: AppColors.text),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}
