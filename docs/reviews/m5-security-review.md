# Review code và bảo mật M5

Ngày review lần 1: 2026-11-17 (commit `ed631b6`, `9645544`, `2462e18`, `3d49c52`)

Ngày review lần 2: 2026-11-17 (commit `64c04e8`, `1f93ec2`, `bb9b13d`, `ad3a15d`, `a526847`)

Ngày review lần 3 (chốt C7): 2026-11-17 (commit `3abba24`)

Nhánh: `m5-cong-dong`

Mốc mã nguồn đối chiếu lần 3: `3abba24` (`HEAD`)

## Kết luận lần 3

**MERGE ĐƯỢC.** Toàn bộ phát hiện mức Cao (**C1–C7**), `BUG-M5-01`, HTTP `413 media_too_large`, `MediaPurpose.receipt`, hai điểm thiết kế PM chốt và toàn bộ cổng chốt tự động đều **Đã đóng / Đạt** trên `3abba24` (kể cả tích hợp thật với Postgres, Redis/BullMQ v5, SeaweedFS và `npm audit --omit=dev --audit-level=high` về `0` lỗ hổng). Các mục **V3–V8** và **T1–T3** tiếp tục theo dõi ở M6.

## Tổng hợp trạng thái lần 3 (C1–C7 & các hạng mục bổ sung)

| Hạng mục | Commit | Trạng thái | Tóm tắt lý do |
|---|---|---|---|
| **C1** Thu hồi socket khi rời/bị loại khỏi đội | `64c04e8` | **Đã đóng** | `evictFromTeam` ngắt toàn bộ socket `user:{id}` và `match:join` kiểm lại DB; mới có unit test mock (thiếu E2E socket thật). |
| **C2** Socket sống quá hạn access token | `64c04e8` | **Đã đóng** | Đặt `expiryTimer` theo `exp`, emit `auth:error`, `disconnect(true)` và `clearTimeout` khi ngắt; có test fake timer. |
| **C3** Lịch tuần trùng `jobId` đang `active` | `1f93ec2`, `a526847` | **Đã đóng** | Đổi sang `post-schedule-{id}-{ms}`; `schedules.int-spec.ts` chạy với Redis/BullMQ thật xác nhận tạo job kỳ kế tiếp trạng thái `delayed`. |
| **C4** Publish lịch không claim row | `1f93ec2`, `a526847` | **Đã đóng** | Claim nguyên tử `updateMany` (`scheduled -> cancelled`) trong `$transaction`; `schedules.int-spec.ts` 2 worker song song trên Postgres thật chỉ tạo 1 bài. |
| **C5** Worker trễ giờ đá gây retry vô ích | `1f93ec2` | **Đã đóng** | Có policy misfire: lịch 1 lần hết hạn, lịch tuần nhảy tới kỳ tương lai; đã có unit test phủ cả 2 nhánh. |
| **C6** Lịch vẫn đăng sau khi tác giả mất quyền | `1f93ec2` | **Đã đóng** | Kiểm lại `teamMember` `active` và `captain|vice` trong transaction publish; lưu ý chưa hủy chủ động ngay khi hạ quyền. |
| **C7** Upload mồ côi làm đầy kho (OWASP A04) | `ad3a15d`, `3abba24` | **Đã đóng** | Nâng `sharp` `^0.35.5` (audit high = 0); `assertOwnedKey` kiểm `ownerId === userId` trong DB; bỏ HEIC (chỉ jpeg/png/webp); `finalize` cho avatar (`PATCH /v1/me`) và receipt (`POST /v1/media/uploads/finalize`); receipt gắn `teamId` và chỉ thành viên active đọc qua `GET /v1/media/receipts/:id`; `cleanupExpired` chạy theo lô tới hết; pass unit + E2E + `media.int-spec.ts` với SeaweedFS thật. |
| **BUG-M5-01** `jobId` chứa dấu `:` bị BullMQ v5 từ chối | `1f93ec2`, `a526847` | **Đã đóng** | `postScheduleJobId` bỏ `:`, dùng `post-schedule-{id}-{ms}`; đã chạy pass qua BullMQ v5 thật trong `test:int`. |
| **`GET` post-schedules** | `1f93ec2`, `3abba24` | **Đã đóng** | Gắn `@TeamRoles('captain', 'vice')` và chỉ trả `status: 'scheduled'` theo quyết định PM; có test E2E metadata và unit test query. |
| **HTTP 413 & `MediaPurpose.receipt`** | `bb9b13d`, `3abba24` | **Đã đóng** | Bỏ `@Max` ở DTO để service trả `413 media_too_large`; receipt gắn `teamId`, tách route riêng `GET /v1/media/receipts/:id`, cập nhật OpenAPI. |

## Phát hiện mức Cao (C1–C7)

### C1. Thành viên đã rời/bị loại khỏi đội vẫn nhận chat realtime — OWASP A01 — **Đã đóng**

- **Bằng chứng sửa (`64c04e8`):**
  - `backend/src/realtime/realtime.service.ts:39-45`: `evictFromTeam(userId, teamId)` rời room `team:{teamId}` rồi gọi `disconnectSockets(true)` trên room `user:{userId}`, buộc mọi socket của user ngắt kết nối và rời mọi room `match:{id}`.
  - `backend/src/members/members.service.ts:120,135`: `remove` và `leave` đều gọi `evictFromTeam` sau khi cập nhật DB thành công.
  - `backend/src/realtime/realtime.gateway.ts:99-121`: `match:join` kiểm tra lại `teamMember` `status: 'active'` trong DB trước khi cho vào room.
  - Unit test: `backend/src/realtime/realtime.service.spec.ts` (mock `socketsLeave` và `disconnectSockets`).
- **Rủi ro còn lại (không chặn C1):** ngắt cả socket ở các đội khác của user (client cần tự reconnect/re-join); chưa có integration test E2E socket thật; nếu sau này thêm luồng mất membership khác (xóa đội, đổi trạng thái trực tiếp) phải nhớ gọi `evictFromTeam`.

### C2. Socket sống quá hạn access token — OWASP A07/A01 — **Đã đóng**

- **Bằng chứng sửa (`64c04e8`):**
  - `backend/src/realtime/realtime.gateway.ts:44-56`: bắt buộc `payload.typ === 'access'` và `typeof payload.exp === 'number'`, tính `delay = Math.max(0, payload.exp * 1000 - Date.now())`, đặt `expiryTimer` phát `auth:error { code: 'token_expired' }` và `client.disconnect(true)`.
  - `backend/src/realtime/realtime.gateway.ts:135-137`: `handleDisconnect` gọi `clearTimeout`, không rò timer.
  - Test: `backend/src/realtime/realtime.gateway.spec.ts` dùng fake timer + JWT `expiresIn: '1s'` đã kiểm tra emit và `disconnect(true)`.
- **Lưu ý:** thu hồi session/token chủ động (logout, đổi mật khẩu, khóa tài khoản) vẫn là phần ngoài phạm vi hiện tại.

### C3. Lịch tuần dùng lại `jobId` của job đang chạy nên không tạo được kỳ kế tiếp — **Đã đóng**

- **Bằng chứng sửa (`1f93ec2`, `a526847`):**
  - `backend/src/schedules/schedules.service.ts:91-93`: `postScheduleJobId(id, scheduledAt)` tạo ID `post-schedule-${id}-${scheduledAt.getTime()}` (không còn dấu `:`, đồng thời đóng **BUG-M5-01**).
  - `backend/src/schedules/schedules.service.ts:131,139,154` và `backend/src/jobs/system.processor.ts:71-73`: `update`, `cancel`, `enqueue` và worker khi lên lịch kỳ kế tiếp đều dùng `postScheduleJobId`.
  - Integration test thật (`backend/src/schedules/schedules.int-spec.ts:104-121`): chạy `SystemProcessor` với Redis/BullMQ v5 và Postgres thật, xác nhận lịch tuần công bố xong và job kỳ kế tiếp được tạo ở trạng thái `delayed`.

### C4. Publish lịch không claim/khóa row, có thể tạo bài trùng — **Đã đóng**

- **Bằng chứng sửa (`1f93ec2`, `a526847`):**
  - `backend/src/schedules/schedules.service.ts:165-169`: claim nguyên tử bằng `tx.postSchedule.updateMany({ where: { id: scheduleId, status: 'scheduled', scheduledAt: { lte: now } }, data: { status: 'cancelled' } })` trong `$transaction`; nếu `claimed.count !== 1` thì thoát ngay, nếu `post.create` lỗi thì transaction rollback trạng thái `scheduled`.
  - Integration test thật (`backend/src/schedules/schedules.int-spec.ts:123-155`): chạy 2 worker BullMQ song song trên Postgres thật cho cả lịch 1 lần và lịch tuần, xác nhận chỉ tạo đúng 1 bài và dời đúng 1 kỳ.

### C5. Worker chạy trễ qua giờ đá làm lịch kẹt và retry vô ích — **Đã đóng**

- **Bằng chứng sửa (`1f93ec2`):**
  - `backend/src/schedules/schedules.service.ts:184-198`: khi `dto.startAt <= now`, lịch một lần giữ `cancelled` và trả `{ published: false, nextAt: null }`; lịch tuần tính số kỳ đã lỡ `periods = Math.floor((now.getTime() - dto.startAt.getTime()) / WEEK_MS) + 1`, dời `startAt`/`endAt`/`scheduledAt` sang kỳ tương lai và đặt lại `status: 'scheduled'` để enqueue kỳ tiếp theo.
  - Unit test: `backend/src/schedules/schedules.service.spec.ts` đã phủ cả misfire lịch 1 lần và lịch tuần trễ nhiều tuần.

### C6. Lịch vẫn đăng sau khi tác giả mất quyền đội — OWASP A01 — **Đã đóng**

- **Bằng chứng sửa (`1f93ec2`):**
  - `backend/src/schedules/schedules.service.ts:171-180`: trong transaction publish, kiểm tra lại `tx.teamMember.findFirst({ where: { teamId: schedule.teamId, userId: schedule.authorId, status: 'active', role: { in: ['captain', 'vice'] } } })`; không còn quyền thì không tạo bài và giữ lịch ở `cancelled`.
  - Unit test: `backend/src/schedules/schedules.service.spec.ts` đã phủ trường hợp tác giả không còn quyền.
- **Rủi ro nhỏ:** chưa chủ động hủy lịch khi `remove`/`leave`/hạ quyền (lịch vẫn hiện `scheduled` cho tới giờ chạy) và chưa ghi audit lý do hủy.

### C7. Tài khoản đăng nhập có thể làm đầy kho bằng upload mồ côi — OWASP A04 — **Đã đóng**

- **Bằng chứng sửa (`ad3a15d`, `3abba24`):**
  - **Dependency & whitelist định dạng (`3abba24`):** nâng `sharp` lên `^0.35.5` (`backend/package.json:61`, `backend/package-lock.json`), `npm audit --omit=dev --audit-level=high` đạt **0 lỗ hổng**; bỏ `image/heic` ở `IMAGE_TYPES` (`backend/src/media/media.dto.ts:5-9`) và khóa `ALLOWED_INPUT_FORMATS = new Set(['jpeg', 'png', 'webp'])` tại `backend/src/media/media.service.ts:252,271` để chặn SVG/GIF/TIFF trước khi re-encode WebP.
  - **Chống IDOR tại `assertOwnedKey` (`3abba24`):** `backend/src/media/media.service.ts:117-122` kiểm khớp `PUBLIC_KEY_PATTERN` và truy vấn `prisma.mediaUpload.findFirst({ where: { publicKey: key, ownerId: userId } })`, trả `403 media_forbidden` nếu sai chủ; đã phủ bằng unit test (`backend/src/media/media.service.spec.ts:138-153`) và integration test thật (`backend/src/media/media.int-spec.ts:169-172`).
  - **Luồng `finalize` cho `avatar` và `receipt` (`3abba24`):**
    - `PATCH /v1/me` (`avatarKey` trong `backend/src/users/users.dto.ts:94-97`, `backend/src/users/users.service.ts:76-84`) gọi `MediaService.useAvatar(userId, dto.avatarKey)` -> `assertOwnedKey` -> `finalize(..., 'avatar')` -> `markReferenced`.
    - `POST /v1/media/uploads/finalize` (`backend/src/media/media.controller.ts:27-33`, `backend/src/media/media.service.ts:144-153`) xác minh và re-encode `avatar`/`receipt`, từ chối `post` (`400 media_purpose_not_supported`).
    - Migration `backend/prisma/migrations/20261117101000_m5_media_receipt_team/migration.sql` + `backend/prisma/schema.prisma:447-465` thêm `team_id` (FK `ON DELETE CASCADE` tới `teams`) cho `media_uploads`; `createImageUpload` bắt buộc `teamId` và kiểm tra thành viên `active` khi `purpose = receipt` (`backend/src/media/media.service.ts:159-165`).
    - `GET /v1/media/public/:id` (`readPublicImage`) chỉ phục vụ `post`/`avatar`; `receipt` bị loại ở truy vấn (`404 media_not_found`) và chỉ đọc được qua `GET /v1/media/receipts/:id` (`readReceipt`) khi đã đăng nhập và là thành viên `active` của đội (`403 media_forbidden` cho người ngoài, kèm `Cache-Control: private, no-store` và `X-Content-Type-Options: nosniff`).
  - **Dọn rác theo lô & hạ tầng (`3abba24`):** `cleanupExpired()` (`backend/src/media/media.service.ts:201-233`) dùng cursor pagination (`CLEANUP_BATCH_SIZE = 100`, `CLEANUP_MAX_BATCHES = 100`), giữ lại bản ghi nếu xóa object S3 thất bại để thử lại kỳ sau; `.env.example:24`, `docker-compose.yml:13` và `backend/src/common/env.ts:57` cấu hình `MEDIA_PUBLIC_URL` (dùng `||` để fallback đúng nếu biến rỗng).
  - **Kiểm thử đầy đủ:** unit test `backend/src/media/media.service.spec.ts` (27 test), E2E `backend/src/media/media.e2e-spec.ts` (7 test), integration test thật với SeaweedFS + Postgres + Sharp `backend/src/media/media.int-spec.ts` (7 test: quarantine -> finalize -> readPublicImage, anonymous S3 GET bị chặn `401/403`, SVG giả PNG bị reject, IDOR bị chặn, avatar, receipt theo thành viên đội, `cleanupExpired`).
- **Lưu ý nhỏ (không chặn merge):**
  - `backend/src/media/media.service.ts:83`: dùng `contentType in IMAGE_TYPES` (nên đổi sang `Object.hasOwn(IMAGE_TYPES, contentType)` để tránh key prototype như `toString`, dù `finalize` vẫn chặn ở Sharp) và chuỗi thông báo lỗi còn nhắc `'hoặc HEIC'`.
  - `backend/prisma/migrations/20261117101000_m5_media_receipt_team/migration.sql`: cột `team_id` có FK `ON DELETE CASCADE` nhưng chưa có index riêng trên `media_uploads(team_id)` (tương tự ghi chú ở **V7**).
  - `backend/src/media/media.service.ts:151`: `finalizeUpload` đánh dấu `referencedAt` ngay khi finalize, nên biên lai/avatar đã finalize nhưng client không gửi bước gắn tiếp theo sẽ không bị `cleanupExpired` xóa.

## Hạng mục bổ sung được kiểm tra ở lần 2–3

- **HTTP 413 & `MediaPurpose.receipt` (`bb9b13d`, `3abba24`) — Đã đóng:** `backend/src/media/media.dto.ts:44-46` bỏ `@Max(MAX_IMAGE_BYTES)` ở `class-validator` để `MediaService.createImageUpload` trả `413 media_too_large`; `receipt` gắn `teamId` và endpoint riêng `GET /v1/media/receipts/:id`; `docs/openapi.json` đã cập nhật; `backend/src/media/media.e2e-spec.ts` (7 test) pass.
- **`GET /teams/:teamId/post-schedules` (`1f93ec2`, `3abba24`) — Đã đóng:** `backend/src/schedules/schedules.controller.ts:12` đã gắn `@TeamRoles('captain', 'vice')` và `backend/src/schedules/schedules.service.ts:116` lọc `status: 'scheduled'` theo chốt của PM; đã phủ bằng `backend/src/schedules/schedules.e2e-spec.ts:41-43` và `backend/src/schedules/schedules.service.spec.ts:41-46`.

## Phát hiện mức Vừa (từ lần 1; V1–V2 đã đóng ở lần 3, V3–V8 giữ theo dõi)

### V1. Chỉ tin MIME/metadata do client cung cấp — **Đã đóng (`ad3a15d`, `3abba24`)**

- **Bằng chứng:** quarantine + Sharp `^0.35.5` (0 High CVE) + whitelist `jpeg/png/webp` (bỏ HEIC) + `X-Content-Type-Options: nosniff` + integration test PUT/GET thật với SeaweedFS (`backend/src/media/media.int-spec.ts`).

### V2. Quyền đọc bucket/public URL không được khai báo rõ — **Đã đóng (`ad3a15d`, `3abba24`)**

- **Bằng chứng:** API trả `MEDIA_PUBLIC_URL` (`/v1/media/public/:id`) cho `post`/`avatar` và `/v1/media/receipts/:id` (yêu cầu JWT + thành viên active) cho `receipt`; `docker-compose.yml:72-73` chỉ bind cổng S3 `8333` trên `127.0.0.1`; `backend/src/media/media.int-spec.ts:155-159` xác nhận anonymous GET trực tiếp vào SeaweedFS bị từ chối `401/403`. Khi lên VPS giữ nguyên cấu hình không mở cổng S3 ra ngoài và đi qua Caddy/API.

### V3. Rate limit chat/upload theo IP và bộ nhớ tiến trình

- **File:dòng:** `backend/src/chat/chat.controller.ts:33-41`, `backend/src/media/media.controller.ts:15-22`, `backend/src/app.module.ts:49,69`.
- **Bằng chứng:** endpoint chat có ngưỡng 30/60 giây và upload 20/60 giây, nhưng guard dùng tracker/storage mặc định. Đổi IP hoặc chạy nhiều replica làm quota bị chia nhỏ; nhiều user chung NAT chia sẻ quota.
- **Cách sửa:** Redis-backed limiter; key chính `userId` (chat có thể thêm `matchId`), IP là lớp phụ. Thêm test 429 và test hai replica dùng chung quota.

### V4. Ghi DB và enqueue/remove job không nguyên tử

- **File:dòng:** `backend/src/schedules/schedules.service.ts:103-140`, `backend/src/jobs/system.processor.ts:68-78`.
- **Bằng chứng:** create/update/cancel và cả re-enqueue lịch tuần trong `SystemProcessor` đều thao tác Redis sau khi transaction DB đã commit. Nếu Redis lỗi sau commit hoặc `queue.remove()` thất bại, lịch tuần có thể dừng im lặng ở trạng thái `scheduled` không còn job.
- **Cách sửa:** transactional outbox + dispatcher/reconciliation quét lịch `scheduled` chưa có job; không nuốt lỗi `queue.remove()` mà không có cơ chế sửa sai.

### V5. `bookingId` được nhận nhưng không xác thực và bị bỏ khi publish

- **File:dòng:** `backend/src/schedules/schedules.dto.ts:6`, `backend/src/schedules/schedules.service.ts:103-109,199-201`, `backend/src/posts/posts.service.ts:113-153`.
- **Bằng chứng:** DTO lịch kế thừa `CreatePostDto`, nhận `bookingId`, nhưng schedule không gọi `bookingFor(teamId, bookingId)` và post tạo ra không gắn booking/pitch.
- **Cách sửa:** bỏ `bookingId` khỏi DTO lịch, hoặc xác thực ownership/status ở create/update/publish.

### V6. Cài đặt thông báo không được thực thi

- **File:dòng:** `backend/src/users/users.service.ts:50-61`, `backend/src/notifications/notification-writer.ts:39-54`, `backend/src/notifications/notifications.service.ts:38-58`, `backend/src/jobs/push.service.ts:63-109`.
- **Bằng chứng:** ba cờ `matchUpdates/teamActivity/community` chỉ được đọc/ghi ở `UsersService`; pipeline tạo realtime/push không lọc theo category. User tắt vẫn nhận thông báo.
- **Cách sửa:** map `NotificationCategory` sang cờ tương ứng và lọc trước khi ghi/phát/push. Thêm test opt-out cho từng category.

### V7. Schema chat thiếu FK/index bảo vệ tính toàn vẹn

- **File:dòng:** `backend/prisma/migrations/20261116230000_m5_match_chat/migration.sql:2-18`, `backend/prisma/schema.prisma:527-541`.
- **Bằng chứng:** `team_id` không có FK tới `teams`; `user_id` có FK nhưng không có index riêng.
- **Cách sửa:** migration mới thêm FK `team_id -> teams(id)` và index `team_id`, `user_id`; nếu cố ý giữ snapshot team đã xóa thì đổi tên/trường snapshot và ghi ADR rõ.

### V8. E2E bảo mật thay guard thật bằng guard giả

- **File:dòng:** `backend/src/chat/chat.e2e-spec.ts:17-35`, `backend/src/media/media.e2e-spec.ts:14-32`, `backend/src/schedules/schedules.e2e-spec.ts:12-26`.
- **Bằng chứng:** test hiện chứng minh routing/validation nhưng không chứng minh JWT, `TeamMemberGuard`, role metadata và throttler hoạt động cùng nhau.
- **Cách sửa:** thêm integration suite với guard thật cho 401/403, outsider, member inactive/just removed, captain/vice/member và 429.

## Phát hiện mức Thấp (từ lần 1, giữ theo dõi)

### T1. Lỗi DB khi join Socket.IO bị biến thành “không có quyền” và không log

- **File:dòng:** `backend/src/realtime/realtime.gateway.ts:63-68,94-110`.
- **Cách sửa:** log structured error + correlation/socket/user ID (không log token), trả mã lỗi phân biệt `temporarily_unavailable`.

### T2. OpenAPI chat thiếu các response lỗi thực tế

- **File:dòng:** `backend/src/chat/chat.controller.ts:33-51`, `docs/openapi.json` phần `/v1/matches/{matchId}/messages`.
- **Cách sửa:** bổ sung Swagger response/error schema và sinh lại OpenAPI/client.

### T3. Policy lịch sử chat cho thành viên mới chưa được chốt

- **File:dòng:** `backend/src/chat/chat.service.ts:79-97`, `docs/adr/0004-realtime-chat-socketio.md:5-7`.
- **Cách sửa:** PO chốt policy; nếu chỉ cho từ lúc tham gia thì lọc `createdAt >= joinedAt`.

## Điểm đã kiểm tra và đạt

- REST chat kiểm membership active của đúng một trong hai đội trước cả list/send: `backend/src/chat/chat.service.ts:23-84`.
- Chat body dùng `@Trim`, `@IsString`, `@MinLength(1)`, `@MaxLength(1000)`: `backend/src/chat/chat.dto.ts:7-17`.
- Presigned PUT: TTL 300 giây; key upload cô lập vào `quarantine/{uuid}.upload`; chữ ký chứa `content-type` và `content-length`: `backend/src/media/media.service.ts:87-102`.
- `/v1/me` lấy theo `userId` từ JWT; chat sender chỉ trả `id/name/avatarUrl`, không lộ email/SĐT.
- Không thấy secret thật được hardcode trong các commit `64c04e8`, `1f93ec2`, `bb9b13d`, `ad3a15d`, `a526847`, `3abba24`.

## Kết quả kiểm tra tự động (lần 3)

Chạy trên nhánh `m5-cong-dong` tại `HEAD 3abba24`:

- `npm test`: **26/26 file, 236/236 test pass** (`media.service.spec.ts` tăng lên 27 test).
- `npm run lint`: **pass, 0 warnings, 0 errors** (132 files, `oxlint --type-aware src/ test/`).
- `npm run test:e2e`: **4/4 file, 19/19 test pass** (`media.e2e-spec.ts` 7 test, `schedules.e2e-spec.ts` 4 test).
- `npm run test:int`: **2/2 file, 10/10 test pass** (`media.int-spec.ts` 7 test chạy thật trên SeaweedFS + Postgres + Sharp; `schedules.int-spec.ts` 3 test chạy thật trên Postgres + Redis/BullMQ v5; xác nhận migration `20261117101000_m5_media_receipt_team` deploy sạch).
- `npm audit --omit=dev --audit-level=high`: **pass, found 0 vulnerabilities**.
- `git diff --check 535ef99..3abba24`: **pass**.

Phần còn chưa kiểm chứng bằng test tự động (ghi nhận ngoài phạm vi cổng chốt M5): socket đang mở sau remove/leave/token expiry qua WebSocket thật (hiện kiểm qua unit test mock/fake timer).
