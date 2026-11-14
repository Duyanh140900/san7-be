import 'package:material_ui/material_ui.dart';

import '../format.dart';

/// Màu huy hiệu "#RRGGBB" → Color (mặc định xanh chủ đạo nếu sai định dạng).
Color crestColorOf(String hex) =>
    Color(int.tryParse('FF${hex.replaceFirst('#', '')}', radix: 16) ?? 0xFF0066CC);

/// Chữ trên huy hiệu: bỏ chữ "FC", lấy chữ đầu của tối đa 2 từ ("FC Mỹ Đình" → "MĐ").
String crestLabel(String name) {
  final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && w.toUpperCase() != 'FC');
  return words.isEmpty
      ? Fmt.initials(name)
      : words.take(2).map((w) => String.fromCharCode(w.runes.first)).join().toUpperCase();
}

/// Huy hiệu đội hình khiên (clip-path như bản vẽ).
class TeamCrest extends StatelessWidget {
  const TeamCrest({super.key, required this.name, required this.color, this.width = 68});
  final String name;
  final String color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _ShieldClipper(),
      child: Container(
        width: width,
        height: width * 76 / 68,
        color: crestColorOf(color),
        alignment: Alignment.center,
        child: Text(
          crestLabel(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: width * 0.32,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Avatar tròn của đội (màu huy hiệu + chữ viết tắt), dùng trên Bảng tin, thông báo.
class TeamAvatar extends StatelessWidget {
  const TeamAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 40,
    this.border,
  });
  final String name;
  final String color;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: crestColorOf(color),
      border: border != null ? Border.all(color: border!, width: 2) : null,
    ),
    alignment: Alignment.center,
    child: Text(
      crestLabel(name),
      style: TextStyle(color: Colors.white, fontSize: size * 0.35, fontWeight: FontWeight.w600),
    ),
  );
}

/// Hàng avatar đội chồng lên nhau.
class TeamAvatarStack extends StatelessWidget {
  const TeamAvatarStack({super.key, required this.teams, this.size = 32});
  final List<({String name, String color})> teams;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    width: teams.isEmpty ? 0 : size + (teams.length - 1) * (size - 10),
    child: Stack(
      children: [
        for (final (i, t) in teams.indexed)
          Positioned(
            left: i * (size - 10),
            child: TeamAvatar(name: t.name, color: t.color, size: size, border: Colors.white),
          ),
      ],
    ),
  );
}

class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.5, 0)
    ..lineTo(s.width, s.height * 0.14)
    ..lineTo(s.width, s.height * 0.60)
    ..lineTo(s.width * 0.5, s.height)
    ..lineTo(0, s.height * 0.60)
    ..lineTo(0, s.height * 0.14)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
