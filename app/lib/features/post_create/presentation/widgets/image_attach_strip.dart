import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/common.dart';
import '../../../media/data/media_repository.dart';

/// Dải ảnh đính kèm: nút thêm + ảnh xem trước có nút xoá. Tải lên chỉ làm khi bấm Đăng.
class ImageAttachStrip extends StatelessWidget {
  const ImageAttachStrip({
    super.key,
    required this.images,
    required this.onChanged,
    this.max = 4,
    this.enabled = true,
    this.picker,
  });

  final List<PickedImage> images;
  final ValueChanged<List<PickedImage>> onChanged;
  final int max;
  final bool enabled;
  final ImagePicker? picker;

  Future<void> _add(BuildContext context) async {
    final files = await (picker ?? ImagePicker()).pickMultiImage(
      limit: max - images.length,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (files.isEmpty) return;
    final next = [...images];
    var skipped = 0;
    for (final f in files) {
      if (next.length >= max) break;
      final bytes = await f.readAsBytes();
      final type = MediaRepository.sniffContentType(bytes);
      if (type == null || bytes.length > MediaRepository.maxBytes) {
        skipped++;
        continue;
      }
      next.add(PickedImage(name: f.name, bytes: bytes, contentType: type));
    }
    onChanged(next);
    if (skipped > 0 && context.mounted) {
      showToast(
        context,
        'Bỏ qua $skipped ảnh: chỉ nhận JPEG, PNG, WebP tối đa 10MB',
        type: ToastType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 88,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (var i = 0; i < images.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.group),
                  child: Image.memory(
                    images[i].bytes,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    semanticLabel: 'Ảnh đính kèm ${i + 1}',
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Semantics(
                    button: true,
                    label: 'Xoá ảnh ${i + 1}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: enabled
                          ? () => onChanged([...images]..removeAt(i))
                          : null,
                      child: SizedBox(
                        width: AppSizes.tapTarget,
                        height: AppSizes.tapTarget,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.text,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppIcon(
                                AppIcons.close,
                                size: 14,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (images.length < max)
          Semantics(
            button: true,
            enabled: enabled,
            label: 'Thêm ảnh',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.group),
              onTap: enabled ? () => _add(context) : null,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.group),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppIcon(
                      AppIcons.image,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${images.length}/$max',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
