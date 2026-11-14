import 'package:flutter/services.dart';

import '../format.dart';

/// Chỉ cho nhập số, hiển thị có dấu chấm ngăn cách: 1250000 → "1.250.000".
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.max = 1000000000});
  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final n = int.parse(digits.length > 10 ? digits.substring(0, 10) : digits);
    if (n > max) return oldValue;
    final text = formatAmount(n);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 1250000 → "1.250.000" (không có "đ").
  static String formatAmount(int n) {
    final s = Fmt.money(n);
    return s.substring(0, s.length - 1);
  }

  static int parse(String text) => int.tryParse(text.replaceAll('.', '')) ?? 0;
}
