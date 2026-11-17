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
      _ => null,
    };
  }

  /// Loại ảnh suy từ nội dung (magic bytes) — đúng cả khi bộ chọn đã chuyển
  /// HEIC sang JPEG mà vẫn giữ đuôi tên cũ. Null nếu không phải jpeg/png/webp.
  static CreateUploadDtoContentType? sniffContentType(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return CreateUploadDtoContentType.imageJpeg;
    }
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return CreateUploadDtoContentType.imagePng;
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return CreateUploadDtoContentType.imageWebp;
    }
    return null;
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
