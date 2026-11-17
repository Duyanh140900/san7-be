import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Ảnh đã chọn, sẵn sàng tải lên.
class PickedImage {
  const PickedImage({
    required this.name,
    required this.bytes,
    required this.contentType,
  });
  final String name;
  final Uint8List bytes;
  final CreateUploadDtoContentType contentType;
}

/// Tải ảnh lên qua URL có chữ ký (presigned) rồi trả khoá object để gắn vào bài đăng.
class MediaRepository {
  MediaRepository(this._api, {Dio? uploader}) : _uploader = uploader ?? Dio();
  final San7Api _api;
  final Dio _uploader; // không đi qua AuthInterceptor: URL đã có chữ ký

  static const maxBytes = 10 * 1024 * 1024;

  /// Loại ảnh backend cho phép, suy từ tên file; null nếu không hỗ trợ.
  static CreateUploadDtoContentType? contentTypeOf(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => CreateUploadDtoContentType.imageJpeg,
      'png' => CreateUploadDtoContentType.imagePng,
      'webp' => CreateUploadDtoContentType.imageWebp,
      'heic' => CreateUploadDtoContentType.imageHeic,
      _ => null,
    };
  }

  /// Trả về `key` của ảnh đã tải lên.
  Future<String> upload(
    PickedImage image, {
    MediaPurpose purpose = MediaPurpose.post,
  }) async {
    final target = await apiCall(
      () => _api.media.mediaCreateUpload(
        body: CreateUploadDto(
          purpose: purpose,
          contentType: image.contentType,
          size: image.bytes.length,
        ),
      ),
    );
    final res = await _uploader.request<dynamic>(
      target.uploadUrl,
      data: Stream.fromIterable([image.bytes]),
      options: Options(
        method: target.method,
        headers: {
          ...target.headers,
          Headers.contentLengthHeader: image.bytes.length,
        },
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
    if (res.statusCode == null) throw StateError('upload failed');
    return target.key;
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(apiProvider)),
);
