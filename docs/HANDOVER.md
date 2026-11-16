# Bàn giao dự án Sân 7

Tài liệu cho người (hoặc Claude/agent) nhận tiếp dự án. Đọc theo thứ tự: `README.md` (cài đặt) → `CLAUDE.md` (quy ước, ghi chú kỹ thuật, đọc kỹ) → `docs/PLAN.md` (kế hoạch, mục 11 là lộ trình) → file này.

Bản vẽ UI (24 màn mobile + 1 desktop): https://claude.ai/artifact/V2U7i6PSSdpKo5GyzhvMsG (mỗi màn là `project/<Tên>.dc.html`; bảng số màn ở PLAN mục 1).

## 1. Đã làm (M0 → M4, đã merge vào `main`)

| Chặng | Nội dung | Vị trí chính |
|---|---|---|
| M0 Nền móng | Monorepo, Docker Compose (postgres+PostGIS, redis, storage S3, api, worker, caddy), đăng nhập Google, JWT + refresh xoay vòng, OpenAPI → client Dart | `backend/src/auth`, `docker-compose.yml`, `scripts/gen-api-client.*` |
| M1 Đội bóng | Tạo đội, thành viên + vai trò (captain/vice/treasurer), lịch & điểm danh, quỹ đội (thu/chi/phạt), realtime Socket.IO | `backend/src/{teams,events,funds,realtime}`, `app/lib/features/team*` |
| M2 Cáp kèo | Đăng kèo (tìm đối/tuyển người/pass sân...), gửi/nhận yêu cầu, chốt kèo trong một transaction (tạo trận + lịch cho hai đội), thông báo trong app + FCM, hàng đợi BullMQ + worker | `backend/src/{posts,notifications,queue,jobs}`, `app/lib/features/{feed,post_create,posts,notifications}` |
| M3 Đặt sân | 12 sân mẫu (PostGIS), bản đồ, khung giờ 90 phút, giữ chỗ 10 phút, chống đặt trùng (advisory lock + `slot_key` unique), vé có mã QR, đổi/huỷ giờ, kèo gắn sân đã đặt | `backend/src/{pitches,bookings}`, `app/lib/features/pitches` |
| M4 Sau trận | Nhập tỉ số + đội kia xác nhận (tranh chấp, khoá), tự trừ quỹ tiền sân, thống kê bàn/kiến tạo/MVP, đánh giá đội, hồ sơ đội, bảng vàng, sổ phạt, nhắc nhập kết quả | `backend/src/matches`, `app/lib/features/{matches,honors}` |

Màn đã làm theo bản vẽ: các màn của M0–M4 (gồm 7, 17, 22 của M4). Chi tiết quy tắc nghiệp vụ từng chặng nằm ở `CLAUDE.md` mục "Ghi chú kỹ thuật".

Kiểm tra lần cuối (trên `m4-sau-tran`): backend 180 test (Vitest), app 27 test, `flutter analyze` và `npm run lint` sạch. Mỗi chặng đều đã chạy thử luồng chính trên máy ảo Android thật và bằng script smoke API.

## 2. Cần làm tiếp

### M5. Cộng đồng (màn 10, 21, 23, 24)
- Ảnh/video: tải lên S3 (SeaweedFS trong Docker; sau đổi R2), nén phía app, URL công khai theo `S3_PUBLIC_URL`.
- Bình luận, cảm xúc + danh sách người thả cảm xúc trên kèo/bài.
- Chat (đội với đội, nhóm đội). Hiện nút "Nhắn tin" ở hồ sơ đội đang tắt ("có ở bản sau"): nối vào chat khi làm xong.
- Hẹn lịch đăng kèo + màn "Kèo của tôi".
- Trang cá nhân (người dùng).

### M6. Ra mắt
- Sign in with Apple, build iOS.
- Chuyển lên VPS (cùng `docker-compose.yml`, `CADDY_SITE=api.tenmien.vn`), sao lưu tự động (thư mục `backups/` đã ignore), Sentry, chính sách riêng tư, đưa lên store.

### Việc dở / nợ kỹ thuật đã biết
- **Push notification trên app** chưa chạy: thiếu `app/android/app/google-services.json` (người nhận tự tạo Firebase project). Backend gửi FCM khi có `FIREBASE_SERVICE_ACCOUNT`.
- **Dữ liệu sân là giả** (12 sân Hà Nội, `npm run seed`): thay bằng dữ liệu thật trước khi ra mắt.
- **Bản đồ** dùng tile OSM công cộng: đổi nhà cung cấp trước khi ra mắt.
- **Thanh toán đặt sân**: bản này trả tại sân (`deposit = 0`). Cần cổng thanh toán nếu muốn cọc online.
- M4 chưa có: nhắn tin giữa đội, danh hiệu cúp, nút "Giữ kèo". Chỉ số "Đúng giờ" hiện = % đánh giá gắn thẻ `on_time`, chưa dựa điểm danh thật.
- Quỹ đội có thể âm số dư sau khi trừ tiền sân tự động (chưa chặn, chủ ý).
- Worker không có Socket.IO nên thông báo do worker ghi chỉ có push FCM, không có realtime trong app.
- Tạo `.mcp.json` (nếu dùng MCP) là việc của người nhận; file đã nằm trong `.gitignore`.

## 3. Cách làm việc (giữ nguyên)

1. Mỗi chặng một nhánh `m5-...`, `m6-...` từ `main`; commit nhỏ, thông điệp rõ.
2. Đổi schema: `npm run prisma:migrate -- --name <ten>`; không sửa migration đã commit.
3. Đổi API: chạy lại `scripts/gen-api-client.ps1|.sh` rồi commit `docs/openapi.json` và `app/lib/api/` (không sửa tay thư mục này).
4. Trước khi chốt chặng: `cd backend && npm test && npm run lint`, `cd app && flutter analyze && flutter test`, chạy thử trên máy ảo, rồi review code.
5. Màn hình bám bản vẽ và token trong `app/lib/core/theme/tokens.dart` (không viết mã màu thô trong widget); chữ giao diện tiếng Việt, định danh tiếng Anh.

## 4. Bẫy hay gặp

- **NestJS 12 là ESM**: import tương đối phải có đuôi `.js`; test dùng `vi.fn()` (Vitest), không phải Jest.
- **Prisma 7**: URL DB ở `backend/prisma.config.ts`; client sinh vào `backend/src/generated/prisma` (không commit, chạy `npm run build` hoặc `npx prisma generate`).
- **Flutter 3.50**: dùng `package:material_ui/material_ui.dart`, không dùng `package:flutter/material.dart`.
- **API không trả `null`** (`OmitNullInterceptor`): trường `string | null` phải khai `@ApiPropertyOptional({ type: String })`, nếu không client Dart sinh model rỗng.
- Dev trên Windows: nếu cổng 3000 bị chiếm đặt `API_PORT` khác; app gọi API qua `http://10.0.2.2` từ máy ảo Android. `kotlin.incremental=false` trong `app/android/gradle.properties` là cố ý (project ở ổ D:, pub cache ở ổ C:).
- Scripts smoke/seed thử chỉ nằm ngoài repo (thư mục tạm của phiên làm việc) nên không có trong git; muốn kiểm tra nhanh luồng chính thì viết lại theo các endpoint trong `docs/openapi.json`.

## 5. Skill nên cài cho Claude Code

Nguồn và lý do chọn: `docs/PLAN.md` mục 14. Đọc lướt `SKILL.md` trước khi cài.

**Dùng cho dự án**

| Nhóm | Skill | Cách cài |
|---|---|---|
| Flutter + Dart (25 skill của Flutter team: `flutter-add-integration-test`, `flutter-add-widget-preview`, `flutter-add-widget-test`, `flutter-apply-architecture-best-practices`, `flutter-build-responsive-layout`, `flutter-fix-layout-issues`, `flutter-implement-json-serialization`, `flutter-setup-declarative-routing`, `flutter-setup-localization`, `flutter-use-http-package`, `dart-add-unit-test`, `dart-build-cli-app`, `dart-collect-coverage`, `dart-fix-runtime-errors`, `dart-generate-test-mocks`, `dart-migrate-to-checks-package`, `dart-resolve-package-conflicts`, `dart-run-static-analysis`, `dart-setup-ffi-assets`, `dart-use-doc-examples`, `dart-use-ffigen`, `dart-use-path-package`, `dart-use-pattern-matching`, `dart-use-primary-constructors`, `dart-write-documentation`) | Trong Claude Code CLI: `/plugin marketplace add flutter/skills` rồi `/plugin install dart-flutter@dart-flutter`. Hoặc `npx skills add flutter/skills`. Nguồn: github.com/flutter/skills, github.com/dart-lang/skills. Cần Flutter/Dart trong PATH để chạy Dart MCP server |
| Postgres | `supabase-postgres-best-practices` | `npx skills add supabase/agent-skills --skill supabase-postgres-best-practices` |
| NestJS | `nestjs-expert` | `npx skills add Jeffallan/claude-skills --skill nestjs-expert` |
| NestJS, Docker, Redis | `nestjs-patterns`, `docker-patterns`, `redis-patterns` | Chép 3 thư mục `skills/<tên>` từ github.com/affaan-m/ECC vào `~/.claude/skills/`. **Không cài cả bộ ECC** (hơn 1.000 skill, có hook) |

**Hỗ trợ giao diện và kiểm thử**

- `awesome-design-md`: `apple/DESIGN.md` làm nguồn theme tokens.
- `impeccable`: `/impeccable critique` và `/impeccable polish` để rà giao diện (có hướng dẫn iOS/Android native).
- `playwright-cli`: kiểm tra trang Swagger hoặc trang quản trị web.

**Không cần cho dự án này:** `design-taste-frontend` (chỉ cho web), `img2threejs`.

**Có sẵn trong Claude Code:** `/code-review` (dùng trước khi chốt mỗi chặng), `/security-review`, `/simplify`, `/run`.
