# Review code và bảo mật M5

Ngày review: 2026-11-17

Nhánh: `m5-cong-dong`

Commit được review: `ed631b6`, `9645544`, `2462e18`, `3d49c52`

Mốc mã nguồn dùng để đối chiếu dòng: `3d49c52` (sau đủ bốn commit)

## Kết luận

**Chưa cho merge/release M5.** Có 7 phát hiện mức **Cao**, tập trung ở vòng đời lịch BullMQ, thu hồi quyền chat realtime và lạm dụng kho upload. REST chat đã kiểm tra membership lại trước khi đọc/gửi; DTO chat đã trim và giới hạn 1–1000 ký tự; `/v1/me` chỉ đọc dữ liệu của chính user từ JWT và không thấy lộ email chéo người dùng.

## Phát hiện mức Cao

### C1. Thành viên đã rời/bị loại khỏi đội vẫn nhận chat realtime — OWASP A01

- **File:dòng:** `backend/src/realtime/realtime.gateway.ts:86-113`, `backend/src/realtime/realtime.service.ts:38-40`, `backend/src/members/members.service.ts:107-135`, `backend/src/chat/chat.service.ts:70-75`.
- **Bằng chứng:** `match:join` chỉ kiểm quyền lúc join. `remove()`/`leave()` chỉ gọi `evictFromTeam()`, mà hàm này chỉ rời room `team:{teamId}`; socket vẫn nằm trong `match:{matchId}` và tiếp tục nhận `chat.message`.
- **Cách sửa:** khi membership mất hiệu lực, lấy các match liên quan và gọi `socketsLeave` cho mọi `match:{id}` mà user không còn quyền; hoặc disconnect toàn bộ socket của user để buộc xác thực/join lại. Thêm integration test: join match → remove/leave team → gửi tin → socket cũ không nhận.

### C2. Socket sống quá hạn access token — OWASP A07/A01

- **File:dòng:** `backend/src/realtime/realtime.gateway.ts:39-52`.
- **Bằng chứng:** JWT chỉ được xác minh khi kết nối; sau đó không có timer theo `exp`, refresh/re-auth hoặc kiểm tra lại trước khi phát dữ liệu. Socket kết nối trước lúc token hết hạn có thể ở lại room vô thời hạn.
- **Cách sửa:** lưu `exp`, đặt timer disconnect/re-auth đúng hạn; hủy timer khi disconnect. Nếu có cơ chế revoke session/token, phát sự kiện buộc ngắt các socket tương ứng. Thêm test bằng fake timer cho token hết hạn khi socket đang mở.

### C3. Lịch tuần dùng lại `jobId` của job đang chạy nên không tạo được kỳ kế tiếp

- **File:dòng:** `backend/src/jobs/system.processor.ts:66-75`, `backend/src/schedules/schedules.service.ts:80-84`.
- **Bằng chứng:** worker đang xử lý `post-schedule:{scheduleId}` lại `queue.add()` với đúng `jobId` đó trước khi job hiện tại complete và được xóa. BullMQ deduplicate job trùng ID đang `active`, nên lịch tuần có thể dừng sau lần đầu. Job failed còn được giữ (`removeOnFail: 100`) cũng chặn ID cũ.
- **Cách sửa:** đưa thời điểm kỳ chạy vào ID, ví dụ `post-schedule:{scheduleId}:{scheduledAtMs}`; lưu/tra cứu ID kỳ hiện tại để update/cancel đúng job. Thêm integration test với Redis/BullMQ thật, không chỉ mock `queue.add`.

### C4. Publish lịch không claim/khóa row, có thể tạo bài trùng

- **File:dòng:** `backend/src/schedules/schedules.service.ts:88-105`.
- **Bằng chứng:** comment nói “khóa lịch” nhưng transaction chỉ `findUnique`. Hai worker cùng đọc `status=scheduled` có thể cùng `post.create`; update cuối cùng ghi đè `publishedPostId`, để lại bài trùng/orphan.
- **Cách sửa:** claim nguyên tử bằng conditional update/version hoặc `SELECT ... FOR UPDATE` trong transaction ngắn trước khi tạo post. Có thể dùng trạng thái `publishing` + unique idempotency key theo schedule occurrence. Thêm test concurrency với hai worker.

### C5. Worker chạy trễ qua giờ đá làm lịch kẹt và retry vô ích

- **File:dòng:** `backend/src/schedules/schedules.service.ts:89-105`, `backend/src/posts/posts.service.ts:36-50`.
- **Bằng chứng:** `publishPostSchedule()` gọi `normalizePost(dto, now)`; nếu worker/Redis ngừng rồi chạy lại sau `startAt`, hàm ném `invalid_time`. BullMQ retry cùng dữ liệu ba lần, lịch vẫn `scheduled`; lịch tuần không được dời sang kỳ hợp lệ tiếp theo.
- **Cách sửa:** định nghĩa policy misfire. Lịch một lần: cancel/expire và ghi audit; lịch tuần: cộng đủ bội số 7 ngày đến kỳ tương lai rồi enqueue lại. Không retry lỗi nghiệp vụ không thể tự hồi phục.

### C6. Lịch vẫn đăng sau khi tác giả mất quyền đội — OWASP A01

- **File:dòng:** `backend/src/schedules/schedules.controller.ts:12-17`, `backend/src/schedules/schedules.service.ts:89-105`.
- **Bằng chứng:** create/update/cancel yêu cầu `captain|vice`, nhưng lúc worker chạy chỉ dùng `authorId` đã lưu và không kiểm tra membership còn `active` hay role còn được phép. Lịch lặp có thể tiếp tục đăng dưới tên user đã bị hạ quyền/rời đội.
- **Cách sửa:** trong transaction publish, kiểm tra lại membership `active` và role `captain|vice`; nếu không còn quyền thì cancel/transfer theo policy và ghi audit. Chủ động xử lý lịch khi remove/leave/changeRole.

### C7. Tài khoản đăng nhập có thể làm đầy kho bằng upload mồ côi — OWASP A04

- **File:dòng:** `backend/src/media/media.controller.ts:15-22`, `backend/src/media/media.dto.ts:12-13`, `backend/src/media/media.service.ts:68-117`.
- **Bằng chứng:** mỗi URL cho phép tối đa 10 MiB, hạn 300 giây, 20 URL/phút; key mới được cấp nhưng không có upload intent/quota/finalize/lifecycle. Một IP có thể ghi xấp xỉ 200 MiB/phút và đổi IP/tài khoản để tiếp tục. Rate limit không thay thế quota dung lượng.
- **Cách sửa:** tạo bảng/record upload intent gồm owner, expected size/type, expiry, trạng thái và object key; quota theo user/ngày và tổng dung lượng; finalize một lần sau kiểm tra object; lifecycle/worker xóa object hết hạn hoặc không được tham chiếu. Rate limit đồng thời theo `userId` và IP bằng Redis.

## Phát hiện mức Vừa

### V1. Chỉ tin MIME/metadata do client cung cấp

- **File:dòng:** `backend/src/media/media.service.ts:79-115` (commit gốc); luồng hiện tại kiểm tra lại bằng `HeadObject` nhưng vẫn chỉ đọc metadata do client đặt.
- **Bằng chứng:** whitelist `Content-Type` và chữ ký không chứng minh byte thực là ảnh. File HTML/polyglot có thể được khai `image/jpeg`; nếu phục vụ công khai hoặc web render sai ngữ cảnh sẽ tạo stored-content/XSS risk.
- **Cách sửa:** upload vào private/quarantine; kiểm magic bytes bằng decoder, giới hạn pixel/decompression bomb, re-encode sang định dạng chuẩn rồi mới publish. Trả `X-Content-Type-Options: nosniff`. Kiểm thử PUT thật với SeaweedFS cho sai type/size; test hiện chỉ kiểm query presign.

### V2. Quyền đọc bucket/public URL không được khai báo rõ

- **File:dòng:** `backend/src/media/media.service.ts:51-65,120-123`, `docker-compose.yml:60-71`, `infra/caddy/Caddyfile:11-14`.
- **Bằng chứng:** code tạo bucket nhưng không đặt bucket policy; trả URL GET trực tiếp, trong khi Caddy chỉ proxy API. Nếu bucket private, URL ảnh không dùng được; nếu operator mở cả bucket để chạy, mọi purpose/prefix trong `media` đều public.
- **Cách sửa:** chốt mô hình: bucket/prefix public chỉ cho ảnh đã duyệt, dữ liệu nhạy cảm ở bucket private và dùng presigned GET ngắn hạn. Policy/IaC phải explicit và có test anonymous GET được phép/bị cấm theo prefix.

### V3. Rate limit chat/upload theo IP và bộ nhớ tiến trình

- **File:dòng:** `backend/src/chat/chat.controller.ts:33-41`, `backend/src/media/media.controller.ts:15-22`, `backend/src/app.module.ts:49,69`.
- **Bằng chứng:** endpoint chat có ngưỡng 30/60 giây và upload 20/60 giây, nhưng guard dùng tracker/storage mặc định. Đổi IP hoặc chạy nhiều replica làm quota bị chia nhỏ; nhiều user chung NAT chia sẻ quota.
- **Cách sửa:** Redis-backed limiter; key chính `userId` (chat có thể thêm `matchId`), IP là lớp phụ. Thêm test 429 và test hai replica dùng chung quota.

### V4. Ghi DB và enqueue/remove job không nguyên tử

- **File:dòng:** `backend/src/schedules/schedules.service.ts:41-68`.
- **Bằng chứng:** create/update/cancel commit DB trước rồi mới thao tác Redis. Queue lỗi có thể để schedule `scheduled` nhưng không có job, hoặc job cũ còn chạy với payload đã đổi.
- **Cách sửa:** transactional outbox + dispatcher/reconciliation; worker vẫn phải idempotent. Không nuốt lỗi `queue.remove()` mà không có cơ chế sửa sai.

### V5. `bookingId` được nhận nhưng không xác thực và bị bỏ khi publish

- **File:dòng:** `backend/src/schedules/schedules.dto.ts:6`, `backend/src/schedules/schedules.service.ts:41-45,93-96`, `backend/src/posts/posts.service.ts:113-153`.
- **Bằng chứng:** DTO lịch kế thừa `CreatePostDto`, nhận `bookingId`, nhưng schedule không gọi `bookingFor(teamId, bookingId)` và post tạo ra không gắn booking/pitch. Đây chưa tạo IDOR trực tiếp vì ID không được dereference, nhưng hợp đồng API sai và dễ phát triển thành IDOR.
- **Cách sửa:** bỏ `bookingId` khỏi DTO lịch, hoặc xác thực ownership/status ở create/update/publish; cấm lịch tuần dùng booking duy nhất hoặc định nghĩa rõ cách tạo booking cho từng kỳ.

### V6. Cài đặt thông báo không được thực thi

- **File:dòng:** `backend/src/users/users.service.ts:50-61`, `backend/src/notifications/notification-writer.ts:39-54`, `backend/src/notifications/notifications.service.ts:38-58`, `backend/src/jobs/push.service.ts:63-109`.
- **Bằng chứng:** ba cờ `matchUpdates/teamActivity/community` chỉ được đọc/ghi ở `UsersService`; pipeline tạo realtime/push không lọc theo category. User tắt vẫn nhận thông báo.
- **Cách sửa:** map `NotificationCategory` sang cờ tương ứng và lọc trước khi ghi/phát/push; làm rõ setting áp dụng cho push, realtime hay cả in-app. Thêm test opt-out cho từng category.

### V7. Schema chat thiếu FK/index bảo vệ tính toàn vẹn

- **File:dòng:** `backend/prisma/migrations/20261116230000_m5_match_chat/migration.sql:2-18`, `backend/prisma/schema.prisma:527-541`.
- **Bằng chứng:** `team_id` không có FK tới `teams`; `user_id` có FK nhưng không có index riêng. Có thể lưu team không tồn tại và delete/cascade user phải scan bảng lớn.
- **Cách sửa:** migration mới thêm FK `team_id -> teams(id)` và index `team_id`, `user_id`; nếu cố ý giữ snapshot team đã xóa thì đổi tên/trường snapshot và ghi ADR rõ.

### V8. E2E bảo mật thay guard thật bằng guard giả

- **File:dòng:** `backend/src/chat/chat.e2e-spec.ts:17-35`, `backend/src/media/media.e2e-spec.ts:14-32`, `backend/src/schedules/schedules.e2e-spec.ts:12-26`.
- **Bằng chứng:** test hiện chứng minh routing/validation nhưng không chứng minh JWT, `TeamMemberGuard`, role metadata và throttler hoạt động cùng nhau.
- **Cách sửa:** thêm integration suite với guard thật cho 401/403, outsider, member inactive/just removed, captain/vice/member và 429.

## Phát hiện mức Thấp

### T1. Lỗi DB khi join Socket.IO bị biến thành “không có quyền” và không log

- **File:dòng:** `backend/src/realtime/realtime.gateway.ts:63-68,94-110`.
- **Bằng chứng:** `.catch(() => null)` fail-closed nhưng che lỗi hạ tầng, gây khó phát hiện sự cố/abuse.
- **Cách sửa:** log structured error + correlation/socket/user ID (không log token), trả mã lỗi phân biệt `temporarily_unavailable`.

### T2. OpenAPI chat thiếu các response lỗi thực tế

- **File:dòng:** `backend/src/chat/chat.controller.ts:33-51`, `docs/openapi.json` phần `/v1/matches/{matchId}/messages`.
- **Bằng chứng:** controller chủ yếu khai báo 201/200, trong khi runtime có 400/401/403/404/409/429.
- **Cách sửa:** bổ sung Swagger response/error schema và sinh lại OpenAPI/client.

### T3. Policy lịch sử chat cho thành viên mới chưa được chốt

- **File:dòng:** `backend/src/chat/chat.service.ts:79-97`, `docs/adr/0004-realtime-chat-socketio.md:5-7`.
- **Bằng chứng:** bất kỳ thành viên active hiện tại đều đọc toàn bộ lịch sử trận, kể cả tin trước ngày họ gia nhập đội. Điều này đúng với ADR hiện tại nhưng có thể vượt kỳ vọng riêng tư.
- **Cách sửa:** PO chốt policy; nếu chỉ cho từ lúc tham gia thì lọc `createdAt >= joinedAt` và lưu/snapshot membership theo thời điểm.

## Điểm đã kiểm tra và đạt

- REST chat kiểm membership active của đúng một trong hai đội trước cả list/send: `backend/src/chat/chat.service.ts:23-84`.
- Chat body dùng `@Trim`, `@IsString`, `@MinLength(1)`, `@MaxLength(1000)`: `backend/src/chat/chat.dto.ts:7-17`. Flutter `Text` render chuỗi dạng text, không thấy XSS trực tiếp; không được đưa body vào WebView/HTML renderer.
- Presigned PUT: TTL 300 giây; key do server sinh dưới `users/{userId}/{purpose}/{uuid}`; chữ ký chứa `content-type` và `content-length`: `backend/src/media/media.service.ts:95-115`.
- `/v1/me` lấy theo `userId` từ JWT, mapper chỉ trả trường đã khai báo; chat sender chỉ trả `id/name/avatarUrl`, không trả email/số điện thoại: `backend/src/users/users.service.ts:10-47`, `backend/src/chat/chat.service.ts:13,100-115`.
- Không thấy secret thật được hardcode trong bốn commit; credential S3/JWT đọc từ biến môi trường.

## Kết quả kiểm tra tự động

Chạy trên `HEAD b0d55f7` của nhánh `m5-cong-dong` (HEAD có các commit sau bốn commit được review):

- `npm test -- --run`: **24/24 file, 204/204 test pass**.
- `npm run test:e2e`: **4/4 file, 12/12 test pass**.
- `npm run lint`: **pass, 0 lỗi**.
- `npm audit --omit=dev --audit-level=high`: **0 vulnerability được báo**.
- `git diff --check ed631b6^..3d49c52`: **pass**.

Các suite chưa kiểm chứng thực tế: BullMQ dedupe khi job đang active, concurrent worker, worker misfire, socket đang mở sau remove/leave/token expiry, SeaweedFS PUT sai `Content-Length`/MIME, bucket policy và quota/lifecycle upload.

## Điều kiện mở merge

1. Sửa đủ C1–C7 và bổ sung regression/integration test tương ứng.
2. Chốt bucket policy + kiểm thử SeaweedFS thật cho signed headers, anonymous GET và file giả MIME.
3. Chạy lại `npm test && npm run lint`, `npm run test:e2e`, rồi `/code-review` và `/security-review`.
