import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../api/api_error.dart';
import '../format.dart';
import '../theme/tokens.dart';
import 'app_toast.dart';
import 'system_state.dart';

/// Thẻ trắng bo 18 (như bản vẽ).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: child,
  );
}

/// Tiêu đề thẻ: "Thành viên" ........ "Xem tất cả"
class CardHeader extends StatelessWidget {
  const CardHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      ?trailing,
    ],
  );
}

/// Nút chữ xanh nhỏ (link) trong thẻ.
class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, required this.onTap, this.color = AppColors.primary});
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
      child: Center(
        widthFactor: 1,
        child: Text(label, style: TextStyle(fontSize: 15, color: color)),
      ),
    ),
  );
}

const _avatarColors = [
  Color(0xFF0066CC),
  Color(0xFF248A3D),
  Color(0xFF1D1D1F),
  Color(0xFFB25000),
  Color(0xFF6E6E73),
  Color(0xFF5E5CE6),
  Color(0xFF8E8E93),
];

/// Avatar tròn: ảnh nếu có, không thì chữ cái đầu trên nền màu cố định theo tên.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 40, this.border});

  final String name;
  final String? url;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _avatarColors[h % _avatarColors.length],
        border: border != null ? Border.all(color: border!, width: 2) : null,
        image: url != null ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: url == null
          ? Text(
              Fmt.initials(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}

/// Nhãn viên thuốc nhỏ (vai trò, trạng thái).
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
    ),
  );
}

/// Segmented control kiểu iOS: nền xám, mục chọn nền trắng có bóng.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    constraints: const BoxConstraints(minHeight: 34),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == index
                          ? const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hiển thị AsyncValue: đang tải (bóng quay) / lỗi (mất mạng hoặc "thẻ đỏ", kèm nút thử lại) / dữ liệu.
/// Dùng các widget trạng thái hệ thống (màn 34), bản gọn để nhét trong danh sách.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => _errorView(ApiError.from(error)),
      _ => const LoadingState(compact: true),
    };
  }

  Widget _errorView(ApiError e) {
    if (e.offline) return OfflineState(onRetry: onRetry, compact: true);
    final server = (e.statusCode ?? 0) >= 500;
    return ErrorState(
      onRetry: onRetry,
      compact: true,
      code: server ? e.statusCode : null,
      message: server
          ? 'Có lỗi khi tải dữ liệu. Đội kỹ thuật đã được báo. Bạn thử lại sau ít phút nhé.'
          : e.message,
    );
  }
}

void showToast(BuildContext context, String message, {ToastType type = ToastType.info}) {
  AppToast.show(type, message, messenger: ScaffoldMessenger.maybeOf(context));
}

/// Chạy một thao tác, báo lỗi bằng toast. Trả về true nếu thành công.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
    if (success != null && context.mounted) showToast(context, success, type: ToastType.success);
    return true;
  } catch (e) {
    if (context.mounted) showToast(context, ApiError.from(e).message, type: ToastType.error);
    return false;
  }
}
