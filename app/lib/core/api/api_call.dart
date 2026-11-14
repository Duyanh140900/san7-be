import 'api_error.dart';

/// Gọi API và đổi mọi lỗi thành [ApiError] có câu tiếng Việt.
Future<T> apiCall<T>(Future<T> Function() request) async {
  try {
    return await request();
  } catch (e) {
    throw ApiError.from(e);
  }
}
