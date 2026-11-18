/// Chuỗi VietQR (EMVCo, NAPAS 247) tự sinh trên máy, không gọi dịch vụ ngoài.
/// Đưa vào `QrImageView(data: ...)`. [bin] là mã ngân hàng 6 số (vd 970436 = Vietcombank).
String buildVietQrPayload({
  required String bin,
  required String account,
  int? amount,
  String? memo,
}) {
  String f(String id, String value) => '$id${value.length.toString().padLeft(2, '0')}$value';

  final bank = f('00', bin) + f('01', account);
  final merchant = f('00', 'A000000727') + f('01', bank) + f('02', 'QRIBFTTA');
  final body = StringBuffer()
    ..write(f('00', '01'))
    ..write(f('01', amount != null && amount > 0 ? '12' : '11'))
    ..write(f('38', merchant))
    ..write(f('53', '704'));
  if (amount != null && amount > 0) body.write(f('54', '$amount'));
  body.write(f('58', 'VN'));
  if (memo != null && memo.isNotEmpty) body.write(f('62', f('08', memo)));
  body.write('6304');
  return '$body${_crc16(body.toString())}';
}

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), 4 ký tự hex HOA.
String _crc16(String s) {
  var crc = 0xFFFF;
  for (final b in s.codeUnits) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

/// Bỏ dấu tiếng Việt, viết hoa: "Văn Nam" → "VAN NAM" (nội dung chuyển khoản không dấu).
String stripVietnamese(String input) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toUpperCase();
}
