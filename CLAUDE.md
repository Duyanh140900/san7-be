# Sân 7

App cộng đồng bóng đá sân 7 (cáp kèo, đặt sân, quản lý đội). Kế hoạch đầy đủ: `docs/PLAN.md`.
Bản vẽ UI (24 màn mobile + 1 desktop): https://claude.ai/artifact/V2U7i6PSSdpKo5GyzhvMsG
(mỗi màn là `project/<Tên>.dc.html`; bảng số màn ở PLAN mục 1).

## Quy ước (PLAN mục 12)

- Giao tiếp và nội dung giao diện bằng **tiếng Việt**; tên biến, hàm, bảng bằng tiếng Anh.
- Tiền luôn là **số nguyên VND** (`bigint`); hiển thị `1.250.000đ`. Thời gian lưu UTC, hiển thị giờ Việt Nam.
- Backend: mỗi module NestJS có controller, service, DTO và test cho service. Logic nhiều bước dùng `prisma.$transaction`. Không viết logic nghiệp vụ trong controller.
- Mọi endpoint ghi dữ liệu của đội đều có guard kiểm tra vai trò trong đội.
- Không commit `.env`, khoá, keystore, `google-services.json`. Có `.env.example`.
- Migration Prisma tạo bằng `prisma migrate dev`, không sửa migration đã commit.
- Flutter: không gọi `dio` trực tiếp trong widget, đi qua repository + provider. Không sửa code trong `app/lib/api/` (code sinh tự động).
- Giao diện bám bản vẽ và theme tokens (`app/lib/core/theme/tokens.dart`, PLAN mục 10).
- Sau mỗi thay đổi lớn: chạy test, `flutter analyze`, lint backend; dùng `/code-review` trước khi chốt chặng.
- Commit nhỏ, thông điệp rõ ràng; mỗi chặng một nhánh (`m0-nen-mong`, `m1-doi-bong`, ...).

## Cấu trúc

```
backend/   NestJS 12 (ESM) + Prisma 7 + PostgreSQL/PostGIS; worker BullMQ chung image (src/worker.ts)
app/       Flutter (Riverpod 3, go_router, dio); package Android/iOS: vn.san7.app
docs/      PLAN.md, openapi.json (sinh từ backend, có commit)
infra/     Caddyfile
scripts/   gen-api-client (.ps1/.sh)
```

## Ghi chú kỹ thuật (khác với kiến thức cũ, đọc kỹ)

- **NestJS 12 là ESM**: import tương đối phải có đuôi `.js`; không có `__dirname` (dùng `import.meta.dirname`); test chạy **Vitest** (`vi.fn()`, không phải jest).
- **Prisma 7**: URL DB nằm ở `backend/prisma.config.ts` (đọc `../.env`), không ở `schema.prisma`. Client sinh vào `backend/src/generated/prisma` (không commit), import từ `../generated/prisma/client.js`; kết nối qua `@prisma/adapter-pg`. Enum import từ `generated/prisma/enums.js`.
- **Flutter 3.50**: Material đã tách thành package `material_ui` → `import 'package:material_ui/material_ui.dart'` (không dùng `package:flutter/material.dart`, đã deprecated).
- **API trả JSON không có `null`**: `OmitNullInterceptor` bỏ trường null; DTO đánh dấu trường đó là tuỳ chọn (`@ApiPropertyOptional`, không dùng `nullable: true`). Lý do: client Dart sinh ra xử lý "vắng mặt" an toàn, còn enum `null` thì lỗi.
- **Client Dart sinh bằng `swagger_parser`** (dio + plain, không cần build_runner, không cần Java) thay cho openapi-generator; cấu hình ở `app/swagger_parser.yaml`. Đổi API xong chạy `scripts/gen-api-client.ps1`.
- Lỗi API có định dạng thống nhất `{ statusCode, code, message, details? }` (`backend/src/common/errors.ts`); service ném `AppError(status, code, message)` với message tiếng Việt.
- Refresh token: chuỗi ngẫu nhiên, lưu sha256, xoay vòng mỗi lần dùng; dùng lại token đã thu hồi → thu hồi mọi phiên của user.
- **Endpoint của đội** (`/teams/:teamId/...`): gắn `@TeamScoped()` ở controller (guard thành viên active + khai báo `teamId` cho OpenAPI) và `@TeamRoles(...)` ở endpoint ghi; lấy người gọi bằng `@CurrentMember()`. Quyền: captain/vice quản lý thành viên + lịch, captain/treasurer quản lý quỹ. App có `TeamRolePermissions` khớp với các quyền này.
- **Tiền** lưu `BigInt` trong Prisma, trả ra API bằng `toMoney()` (số nguyên). Số dư quỹ `teams.fund_balance` cập nhật trong cùng transaction với khoản thu/chi/phạt (`balanceEffect`).
- **Realtime**: Socket.IO ở `/v1/socket`, auth `{ token }`; service gọi `RealtimeService.toTeam(...)` sau khi ghi xong. App: `teamRealtimeSyncProvider` (watch ở `AppShell`) tự invalidate provider khi có sự kiện.
- **Swagger**: trường `string | null` phải ghi rõ `@ApiPropertyOptional({ type: String })`, nếu không client Dart sinh ra model rỗng.
- Android: `kotlin.incremental=false` trong `app/android/gradle.properties` (project ở ổ D:, pub cache ở ổ C: làm hỏng cache incremental).

## Lệnh hay dùng

```bash
# Dịch vụ (cần Docker Desktop)
cp .env.example .env              # rồi điền giá trị
docker compose up -d --build      # postgres, redis, storage, api, worker, caddy
docker compose logs -f api

# Backend chạy ngoài Docker (chỉ cần postgres + redis trong Docker)
docker compose up -d postgres redis storage
cd backend && npm install && npx prisma migrate deploy && npm run start:dev   # http://localhost:3000/docs
npm test && npm run lint
npm run prisma:migrate -- --name <ten>    # tạo migration mới

# App (máy ảo Android gọi máy Windows qua 10.0.2.2)
cd app
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
flutter analyze && flutter test
```
