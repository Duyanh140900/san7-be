import 'package:dio/dio.dart';

/// Lỗi đã chuyển sang câu tiếng Việt để hiện cho người dùng.
class ApiError implements Exception {
  const ApiError(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  factory ApiError.from(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return ApiError(
          data['message'] as String,
          code: data['code'] as String?,
          statusCode: error.response?.statusCode,
        );
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => const ApiError('Mạng chậm, thử lại sau'),
        DioExceptionType.connectionError => const ApiError(
          'Không kết nối được máy chủ. Kiểm tra mạng.',
        ),
        _ => ApiError('Có lỗi xảy ra (${error.response?.statusCode ?? '—'})'),
      };
    }
    return const ApiError('Có lỗi xảy ra, thử lại sau');
  }

  @override
  String toString() => message;
}
