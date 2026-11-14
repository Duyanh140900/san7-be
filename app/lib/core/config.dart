/// Cấu hình truyền lúc build bằng --dart-define (xem app/README.md).
abstract final class AppConfig {
  /// Máy ảo Android gọi máy Windows qua 10.0.2.2.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Web client ID (Google Cloud Console): dùng làm serverClientId để lấy ID token.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
}
