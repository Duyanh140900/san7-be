# Sân 7

App cộng đồng bóng đá sân 7: cáp kèo, đặt sân, quản lý đội, kết quả và bảng vàng.
Kế hoạch đầy đủ nằm ở [`docs/PLAN.md`](docs/PLAN.md); quy ước và ghi chú kỹ thuật ở [`CLAUDE.md`](CLAUDE.md).

| Thư mục | Nội dung |
|---|---|
| `backend/` | API NestJS 12 (ESM) + Prisma 7 + PostgreSQL/PostGIS; worker BullMQ dùng chung image |
| `app/` | Ứng dụng Flutter (Riverpod, go_router, dio), package `vn.san7.app` |
| `infra/` | Cấu hình Caddy (reverse proxy) |
| `docs/` | `PLAN.md`, `openapi.json` (sinh từ backend) |
| `scripts/` | Sinh client API cho Flutter |

## Yêu cầu

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (hoặc Docker Engine + Compose v2)
- Node.js 24 và npm (chạy backend ngoài Docker, chạy test)
- Flutter 3.50+ và Android Studio / Xcode (chạy app)
- Một Google Cloud project có OAuth **Web client ID** (đăng nhập Google)

## 1. Cấu hình môi trường

```bash
cp .env.example .env
```

Mở `.env` và đổi:

- `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `S3_SECRET_KEY`: mật khẩu tuỳ ý (nhớ sửa luôn trong `DATABASE_URL`, `REDIS_URL`).
- `JWT_ACCESS_SECRET`: chuỗi ngẫu nhiên dài, tạo bằng:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

- `GOOGLE_WEB_CLIENT_ID`: Web client ID lấy ở Google Cloud Console.
- `API_PORT`: đổi nếu cổng 3000 đã bị chiếm.
- `FIREBASE_SERVICE_ACCOUNT` (tuỳ chọn): JSON service account Firebase mã hoá base64 trên một dòng. Để trống thì không gửi push, thông báo trong app vẫn chạy.

> Không commit `.env`, keystore, `google-services.json` (đã có trong `.gitignore`).

## 2. Chạy toàn bộ dịch vụ bằng Docker

```bash
docker compose up -d --build      # postgres, redis, storage, api, worker, caddy
docker compose logs -f api
```

API qua Caddy tại `http://localhost` (tiền tố `/v1`). Tài liệu Swagger: `http://localhost/docs`.
Migration chạy khi container `api` khởi động.

## 3. Hoặc chạy backend ngoài Docker (phát triển)

Chỉ cần dịch vụ phụ trong Docker:

```bash
docker compose up -d postgres redis storage
cd backend
npm install
npx prisma migrate deploy
npm run start:dev                 # http://localhost:3000/docs
npm run start:worker:dev          # worker nền (tuỳ chọn, cửa sổ khác)
```

Kiểm tra chất lượng:

```bash
cd backend
npm test && npm run lint
```

Tạo migration mới sau khi sửa `prisma/schema.prisma`:

```bash
npm run prisma:migrate -- --name <ten>
```

### Dữ liệu sân mẫu (12 sân Hà Nội, dữ liệu giả)

```bash
npm run build && npm run seed
# hoặc khi chạy bằng Docker:
docker compose exec api node dist/seed.js
```

Chạy lại được, không tạo trùng. Thay bằng dữ liệu thật trước khi ra mắt.

## 4. Chạy app Flutter

```bash
cd app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2 \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

- Máy ảo Android gọi máy chủ Windows/macOS qua `10.0.2.2`; máy thật dùng IP LAN của máy chạy Docker.
- Đặt vị trí máy ảo để thử bản đồ: `adb emu geo fix 105.789 20.981`.
- Push notification cần thêm `app/android/app/google-services.json` của Firebase project (không nằm trong repo).

```bash
flutter analyze && flutter test
```

### Đổi API thì sinh lại client

Không sửa tay `app/lib/api/` (code sinh tự động). Sau khi đổi API backend:

```powershell
scripts/gen-api-client.ps1       # Windows
```

```bash
scripts/gen-api-client.sh        # macOS / Linux
```

## 5. Triển khai (VPS)

Dùng cùng `docker-compose.yml`. Trong `.env` đặt `NODE_ENV=production`, `CADDY_SITE=api.tenmien.vn` (Caddy tự cấp HTTPS), mật khẩu mạnh, `S3_PUBLIC_URL` trỏ đúng địa chỉ công khai của kho file. Có profile `tunnel` cho Cloudflare Tunnel (`CLOUDFLARE_TUNNEL_TOKEN`).

## Lưu ý

- Tiền luôn là số nguyên VND; thời gian lưu UTC, hiển thị giờ Việt Nam.
- Bản đồ dùng tile OpenStreetMap công cộng, đủ cho chạy thử; đổi nhà cung cấp trước khi ra mắt.
- Mỗi chặng phát triển một nhánh (`m0-nen-mong`, `m1-doi-bong`, ...).
