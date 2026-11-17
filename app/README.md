# Sân 7 · App Flutter

Riverpod 3 + go_router + dio. Package Android/iOS: `vn.san7.app`.

## Chạy

```bash
flutter pub get
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
# Điện thoại thật cùng mạng Wi-Fi: thêm --dart-define=API_BASE_URL=http://<IP máy Windows>:3000
```

### Điện thoại cắm USB (backend chạy trên máy này)

Không có `--dart-define=API_BASE_URL` thì app gọi `http://10.0.2.2:3000` (địa chỉ của máy ảo) và báo "không kết nối được máy chủ". Với điện thoại thật qua USB:

```bash
adb reverse tcp:3001 tcp:3001   # API
adb reverse tcp:8333 tcp:8333   # kho ảnh (presigned URL)
flutter build apk --debug   --dart-define=API_BASE_URL=http://localhost:3001   --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Rút/cắm lại cáp thì chạy lại hai lệnh `adb reverse` (kiểm tra bằng `adb reverse --list`).

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
