import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bộ icon nét mảnh lấy nguyên path từ bản vẽ (viewBox 24, nét 1.8).
enum AppIcons {
  home('<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>'),
  pin(
    '<path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>',
  ),
  plus('<path d="M12 5v14M5 12h14"/>'),
  team(
    '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.3-5.5 6.5-5.5s5.9 1.9 6.5 5.5M16 4.6a3.5 3.5 0 0 1 0 6.8M18 14.8c1.9.7 3.2 2.4 3.5 5.2"/>',
  ),
  trophy(
    '<path d="M8 4h8v5a4 4 0 0 1-8 0z"/><path d="M8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M8.5 20h7M10 17h4"/>',
  ),
  back('<path d="m15 5-7 7 7 7"/>'),
  lock('<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>'),
  qr(
    '<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/>',
  ),
  ball('<circle cx="12" cy="12" r="8"/><path d="m12 7 3.5 2.5-1.3 4h-4.4l-1.3-4z"/>'),
  more(
    '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
  ),
  search('<circle cx="11" cy="11" r="6.5"/><path d="m20 20-4.2-4.2"/>'),
  chevronRight('<path d="m9 5 7 7-7 7"/>'),
  arrowUp('<path d="M12 19V5M6 11l6-6 6 6"/>'),
  warning('<path d="M12 4 3 20h18z"/><path d="M12 10v4M12 17h.01"/>'),
  bell('<path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5h4"/>'),
  clock('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
  info('<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/>'),
  checkCircle('<circle cx="12" cy="12" r="8.5"/><path d="m8 12.5 2.8 2.8L16.5 9.5"/>'),
  wallet('<rect x="3" y="6" width="18" height="14" rx="2.5"/><path d="M3 10h18M16 15h2"/>'),
  cup('<path d="M7 3h10l-1 18H8z"/><path d="M7.5 9h9"/>'),
  calendar('<rect x="4" y="5" width="16" height="15" rx="2"/><path d="M4 10h16M9 3v4M15 3v4"/>'),
  heart(
    '<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.4 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>',
  ),
  comment(
    '<path d="M5 5h14a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1h-8l-4.5 3.5V16H5a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1z"/>',
  ),
  image(
    '<rect x="4" y="5" width="16" height="14" rx="2"/><circle cx="9" cy="10" r="1.6"/><path d="m4.5 17 4.5-4.5 3.5 3.5 2.5-2.5 5 4"/>',
  ),
  chatBox('<path d="M4 5h16v11H9l-5 4z"/>'),
  close('<path d="M6 6l12 12M18 6 6 18"/>');

  const AppIcons(this.body);
  final String body;
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 20, this.color, this.strokeWidth = 1.8});

  final AppIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF1D1D1F);
    final hex = '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="$hex" stroke-opacity="${c.a}" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
