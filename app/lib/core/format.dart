/// Định dạng tiền và thời gian theo quy ước (CLAUDE.md): tiền `1.250.000đ`, giờ Việt Nam.
abstract final class Fmt {
  /// 1250000 → "1.250.000đ"
  static String money(int vnd) {
    final neg = vnd < 0;
    final digits = vnd.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${neg ? '−' : ''}$bufđ';
  }

  /// Có dấu: +200.000đ / −300.000đ
  static String signedMoney(int vnd) => vnd >= 0 ? '+${money(vnd)}' : money(vnd);

  /// Thời điểm (UTC) đổi sang giờ Việt Nam; các trường của kết quả đọc như giờ VN.
  static DateTime vn(DateTime t) => t.toUtc().add(const Duration(hours: 7));

  static const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// "T7"
  static String weekday(DateTime t) => _weekdays[vn(t).weekday - 1];

  /// "22/11"
  static String dayMonth(DateTime t) {
    final v = vn(t);
    return '${v.day}/${v.month}';
  }

  /// "19:00"
  static String time(DateTime t) {
    final v = vn(t);
    return '${_pad2(v.hour)}:${_pad2(v.minute)}';
  }

  /// "T7 22/11 · 19:00 – 20:30"
  static String eventTime(DateTime start, DateTime end) =>
      '${weekday(start)} ${dayMonth(start)} · ${time(start)} – ${time(end)}';

  /// "T7 22/11 · 19:00"
  static String slot(DateTime start) => '${weekday(start)} ${dayMonth(start)} · ${time(start)}';

  /// "Vừa xong" / "12 phút trước" / "3 giờ trước" / "Hôm qua" / "22/11"
  static String ago(DateTime t, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final d = n.difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    final days = _dateOnly(vn(n)).difference(_dateOnly(vn(t))).inDays;
    if (days == 1) return 'Hôm qua';
    return dayMonth(t);
  }

  /// Thời gian còn lại: "1 giờ 45 phút" / "12 phút" / "dưới 1 phút"
  static String remaining(Duration d) {
    if (d.inMinutes < 1) return 'dưới 1 phút';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m phút';
    return m == 0 ? '$h giờ' : '$h giờ $m phút';
  }

  /// 00:00 giờ VN của ngày chứa [t], dạng thời điểm UTC.
  static DateTime vnDayStart(DateTime t) {
    final v = vn(t);
    return DateTime.utc(v.year, v.month, v.day).subtract(const Duration(hours: 7));
  }

  /// Ngày theo giờ VN dạng tham số API: "2026-11-22"
  static String dateParam(DateTime t) {
    final v = vn(t);
    return '${v.year}-${_pad2(v.month)}-${_pad2(v.day)}';
  }

  /// 350 → "350 m", 1230 → "1,2 km"
  static String distance(int meters) =>
      meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// "Thứ Bảy, 22/11"
  static String longDay(DateTime t) {
    const names = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
    return '${names[vn(t).weekday - 1]}, ${dayMonth(t)}';
  }

  /// "Hôm nay" / "Ngày mai" / "T7 22/11" cho ngày của [t] (theo giờ VN).
  static String relativeDay(DateTime t, {DateTime? now}) {
    final today = _dateOnly(vn(now ?? DateTime.now()));
    final days = _dateOnly(vn(t)).difference(today).inDays;
    if (days == 0) return 'Hôm nay';
    if (days == 1) return 'Ngày mai';
    return '${weekday(t)} ${dayMonth(t)}';
  }

  /// "còn 8 ngày" / "hôm nay" / "ngày mai" / "đã qua"
  static String countdown(DateTime start, {DateTime? now}) {
    final today = _dateOnly(vn(now ?? DateTime.now()));
    final day = _dateOnly(vn(start));
    final days = day.difference(today).inDays;
    if (days < 0) return 'đã qua';
    if (days == 0) return 'hôm nay';
    if (days == 1) return 'ngày mai';
    return 'còn $days ngày';
  }

  /// Kỳ quỹ tháng hiện tại "2026-11" theo giờ VN.
  static String currentPeriod({DateTime? now}) {
    final v = vn(now ?? DateTime.now());
    return '${v.year}-${_pad2(v.month)}';
  }

  /// "2026-11" → "tháng 11"
  static String periodLabel(String period) => 'tháng ${int.parse(period.split('-')[1])}';

  /// Chữ cái đầu để làm avatar: "Đức Hùng" → "ĐH"
  static String initials(String name) {
    // Chỉ lấy từ bắt đầu bằng chữ cái: "Văn Nam (thử)" → "VN"
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => RegExp(r'^\p{L}', unicode: true).hasMatch(p))
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return _first(parts.first).toUpperCase();
    return (_first(parts[parts.length - 2]) + _first(parts.last)).toUpperCase();
  }

  static String _first(String s) => String.fromCharCode(s.runes.first);
  static DateTime _dateOnly(DateTime v) => DateTime.utc(v.year, v.month, v.day);
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}
