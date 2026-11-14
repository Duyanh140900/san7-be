# Sân 7 · App Flutter

Riverpod 3 + go_router + dio. Package Android/iOS: `vn.san7.app`.

## Chạy

```bash
flutter pub get
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
# Điện thoại thật cùng mạng Wi-Fi: thêm --dart-define=API_BASE_URL=http://<IP máy Windows>:3000
```

- `API_BASE_URL` mặc định `http://10.0.2.2:3000` (máy ảo Android gọi về máy Windows).
- `GOOGLE_WEB_CLIENT_ID`: **Web** client ID trong Google Cloud Console (giống `GOOGLE_WEB_CLIENT_ID` của backend). Ngoài ra phải có một **Android** OAuth client cùng dự án với package `vn.san7.app` và SHA-1 của keystore đang ký app.

## Cấu trúc

```
lib/
  api/        client sinh từ docs/openapi.json (KHÔNG sửa tay; chạy ../scripts/gen-api-client.ps1)
  core/       theme (tokens), router, api (dio + tự refresh token), auth, widgets dùng chung
  features/<tên>/{data,presentation}
```

## Kiểm tra

```bash
flutter analyze
flutter test
```
