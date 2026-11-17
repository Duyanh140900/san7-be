# Review code và bảo mật M5

Ngày review: 2026-11-17  
Nhánh: `m5-cong-dong`  
Phạm vi: backend thay đổi từ `19ace3f` đến `b0d55f7`, trọng tâm chat Socket.IO, presigned upload, bình luận/cảm xúc, lịch đăng và `/v1/me/*`.

## Kết luận

**Chưa cho merge.** Có 4 nhóm lỗi Chặn: file upload chưa xác minh nội dung thật, kho upload có thể bị lạm dụng để làm đầy dung lượng, quyền đọc chat qua Socket.IO không bị thu hồi đầy đủ, và lịch đăng vẫn chạy sau khi quyền của tác giả bị thu hồi.

Các kiểm tra tự động hiện đều đạt, nhưng chưa bao phủ các tình huống thu hồi quyền và upload giả MIME nêu dưới đây.

## Chặn

### 1. Upload tin hoàn toàn vào MIME do client khai báo (OWASP A04/A08 — Unrestricted File Upload)

- `backend/src/media/media.service.ts:82-107`: chữ ký chỉ khóa `Content-Type` và `Content-Length`; nội dung byte không được kiểm tra.
- `backend/src/media/media.service.ts:159-180`: bước xác nhận chỉ đọc lại `ContentType`/`ContentLength` từ metadata của chính object. Kẻ tấn công có thể PUT HTML, polyglot hoặc dữ liệu hỏng nhưng khai `image/jpeg`, rồi vượt qua bước này.
- `backend/src/media/media.service.ts:113-125`: API trả URL xem công khai ngay, trước khi có bước quarantine/scan/re-encode.

Ảnh hưởng: kho công khai có thể phát tán nội dung không phải ảnh; về sau web/desktop có nguy cơ stored XSS/MIME sniffing, còn app phải giải mã file không tin cậy.

Cần sửa trước merge: upload vào vùng private/quarantine; worker kiểm tra magic bytes bằng thư viện giải mã ảnh, giới hạn kích thước pixel, re-encode sang định dạng chuẩn và chỉ khi đạt mới chuyển sang key public. Khi phục vụ file cần `X-Content-Type-Options: nosniff`; không coi metadata S3 là bằng chứng định dạng.

### 2. Tài khoản đăng nhập có thể làm đầy kho bằng object mồ côi (OWASP A04 — Resource Exhaustion)

- `backend/src/media/media.controller.ts:15-22`: mỗi client được xin 20 URL/phút.
- `backend/src/media/media.dto.ts:12-13`: mỗi URL cho phép tới 10 MiB và sống 5 phút.
- `backend/src/media/media.service.ts:71-120`: cấp key mới ngay nhưng không ghi upload intent, quota hay trạng thái sử dụng.
- `backend/src/media/media.service.ts:139-191`: chỉ kiểm tra object khi gắn vào bài; không có luồng xóa object không bao giờ được gắn.

Một IP có thể tạo khoảng 200 MiB/phút; thay IP/tài khoản tiếp tục tăng không giới hạn. Rate limit hiện tại không thay thế quota dung lượng.

Cần sửa trước merge: lưu `media_uploads` với owner, expected size, expiry và trạng thái; áp quota theo user/ngày và tổng dung lượng; chỉ cho finalize một lần; worker xóa upload hết hạn/không được tham chiếu. Rate limit theo `userId` và IP.

### 3. Thu hồi thành viên hoặc token hết hạn không thu hồi quyền nhận chat realtime (OWASP A01/A07)

- `backend/src/realtime/realtime.gateway.ts:39-48`: JWT chỉ được kiểm tra lúc kết nối; `exp` không được dùng để ngắt socket khi token hết hạn.
- `backend/src/realtime/realtime.gateway.ts:85-113`: sau khi join `match:{id}`, socket ở trong room cho tới khi tự rời/ngắt kết nối.
- `backend/src/realtime/realtime.service.ts:38-40`: khi bị mời/rời đội chỉ bị đưa khỏi `team:{id}`, không bị đưa khỏi các room `match:*` liên quan.
- `backend/src/members/members.service.ts:107-135`: cả remove và leave đều chỉ gọi `evictFromTeam`.

Ảnh hưởng: người đã bị loại khỏi đội vẫn nhận tin nhắn mới của hai đội; socket đã kết nối có thể sống quá hạn access token 15 phút.

Cần sửa trước merge: theo dõi các match room của user/team và evict khi membership đổi; ngắt hoặc bắt buộc re-auth khi JWT hết hạn; kiểm tra lại membership trước khi phát dữ liệu nhạy cảm hoặc dùng adapter có cơ chế room authorization/revocation. Thêm test remove/leave và token expiry khi socket đang mở.

### 4. Lịch đăng tiếp tục thực thi sau khi tác giả mất quyền đội (OWASP A01 — Broken Access Control)

- `backend/src/schedules/schedules.controller.ts:12-17`: lúc tạo/sửa/hủy có kiểm tra `captain`/`vice`, đúng yêu cầu.
- `backend/src/schedules/schedules.service.ts:149-168`: lúc worker chạy chỉ đọc schedule/team rồi tạo post bằng `authorId` đã lưu; không kiểm tra tác giả còn là thành viên active và còn vai trò được phép.

Một phó đội có thể tạo lịch lặp, sau đó bị hạ quyền hoặc mời khỏi đội nhưng lịch vẫn đăng bài vô thời hạn dưới tên họ.

Cần sửa trước merge: trong cùng transaction publish, kiểm tra membership `active` và role `captain|vice`; nếu không còn quyền thì cancel schedule và ghi audit event. Khi remove/leave/downgrade nên chủ động hủy hoặc chuyển quyền lịch theo policy đã chốt. Thêm test cho cả lịch một lần và lặp tuần.

## Nên sửa

### 1. Socket.IO mở CORS và bỏ rate limit cho toàn gateway

- `backend/src/realtime/realtime.gateway.ts:24-25`: `@SkipThrottle()` cùng `cors: { origin: true }`.
- `backend/src/realtime/realtime.gateway.ts:55-124`: `team:join`, `match:join` và leave không có limiter riêng; mỗi join gây truy vấn DB.

Giới hạn origin bằng allowlist cấu hình; thêm limiter theo socket/user cho event join/leave và giới hạn số room/socket. HTTP gửi chat đã có 30 tin/phút và DTO đã giới hạn 1–1000 ký tự (`backend/src/chat/chat.controller.ts:33-41`, `backend/src/chat/chat.dto.ts:7-17`).

### 2. Cập nhật lịch và queue không nguyên tử; worker không khóa/claim row

- `backend/src/schedules/schedules.service.ts:99-127`: ghi DB rồi mới add/remove job; queue lỗi có thể để lịch tồn tại nhưng không chạy, hoặc lịch mới không có job.
- `backend/src/schedules/schedules.service.ts:148-169`: chú thích nói “khóa lịch” nhưng chỉ `findUnique`; update/cancel đồng thời với worker có thể công bố payload cũ.

Dùng outbox hoặc reconciliation job; claim schedule bằng conditional update/version trong transaction trước khi tạo post. Có test queue failure và race update/cancel/publish.

### 3. Schema chat thiếu ràng buộc và index cho khóa ngoại

- `backend/prisma/migrations/20261116230000_m5_match_chat/migration.sql:2-18`: `team_id` không có FK; `user_id` có FK nhưng không có index.
- `backend/prisma/schema.prisma:529-543`: model cũng không có relation team/index user.

Thêm FK `team_id -> teams.id`, index `team_id` và `user_id` (ít nhất index `user_id` để delete/cascade không quét toàn bảng). Nếu cố ý giữ snapshot team đã xóa, cần ghi rõ ADR và dùng cột snapshot không giả dạng FK.

### 4. Cấu hình S3 chưa fail-fast và chưa bắt buộc HTTPS ở production

- `backend/src/common/env.ts:24-28,53-58`: chỉ cần `S3_ENDPOINT` là bật, nhưng không bắt buộc public URL, access key, secret key; cũng không kiểm tra scheme.

Khi storage bật, bắt buộc đủ biến và URL hợp lệ; production chỉ nhận HTTPS cho `S3_PUBLIC_URL`. Việc này tránh presigned URL bị truyền qua kênh rõ và tránh API khởi động ở trạng thái upload chắc chắn lỗi.

### 5. Realtime bình luận/cảm xúc hiện không có đường join room post

- `backend/src/realtime/realtime.service.ts:26-28`: phát vào `post:{postId}`.
- `backend/src/realtime/realtime.gateway.ts:55-124`: chỉ có room team và match, không có `post:join`.

Sự kiện M5 này hiện không tới client nào. Thêm join/leave có validation, limiter và test; hoặc bỏ phát realtime nếu app chủ động reload.

### 6. Test e2e quyền đang thay guard thật bằng guard giả

- `backend/src/chat/chat.e2e-spec.ts:17-34`
- `backend/src/media/media.e2e-spec.ts:14-32`
- `backend/src/schedules/schedules.e2e-spec.ts:12-26`

Các test xác nhận routing/validation nhưng không chứng minh JWT, `TeamMemberGuard` và role metadata hoạt động cùng nhau. Bổ sung integration test với guard thật cho 401/403, outsider, member inactive, vice/captain và member vừa bị remove.

## Gợi ý

- `backend/src/community/community.dto.ts:18-23`: thêm `@MinLength(1)` sau trim để không lưu bình luận rỗng.
- `backend/src/community/community.service.ts:100-105`: gọi `ensurePost` trước khi xóa reaction để phản hồi nhất quán với set/list.
- `backend/prisma/migrations/20261116210000_m5_comments_reactions/migration.sql:20-42`: reaction polymorphic không có FK tới post/comment; cần cleanup rõ ràng khi xóa target hoặc đổi sang bảng relation tách biệt.
- `backend/src/users/users.service.ts:10-68`: `/v1/me`, thống kê và notification settings đều scope bằng `userId` từ JWT; mapper chỉ trả trường đã khai báo. Không thấy rò rỉ chéo user trong diff hiện tại.
- `backend/src/community/community.service.ts:64-83`: quyền xóa comment đúng yêu cầu: tác giả comment hoặc tác giả bài; truy vấn gắn cả `commentId` và `postId`, không thấy IDOR.
- `backend/src/chat/chat.service.ts:23-84`: REST chat kiểm tra thành viên active của đúng hai đội trước đọc/gửi; trận canceled không gửi được. Phần này đạt, ngoại trừ thu hồi room realtime đã nêu ở mục Chặn.
- Trước M6/VPS, pin version/digest cho SeaweedFS và cloudflared thay vì `latest`, đồng thời harden container bằng non-root, `no-new-privileges`, `cap_drop` và giới hạn tài nguyên (`docker-compose.yml:60-71,126-131`).

## Kết quả kiểm tra

- `npm test`: **24/24 file, 204/204 test đạt**.
- `npm run test:e2e`: **4/4 file, 12/12 test đạt**.
- `npm run lint`: **đạt**.
- `npm audit --omit=dev --audit-level=high`: **0 lỗ hổng dependency được báo**.
- `git diff --check 19ace3f..HEAD`: có 1 trailing whitespace ở `docs/design/san7-ui.html:126`; không thuộc backend nhưng nên dọn trước merge.
- Không thấy secret thật được thêm trong diff; các giá trị `access`/`secret` chỉ nằm trong fixture test.

## Điều kiện mở merge

1. Sửa đủ 4 mục Chặn và có test hồi quy tương ứng.
2. Chạy lại `npm test && npm run test:e2e && npm run lint`.
3. Smoke-test: outsider/member bị remove không nhận chat; token hết hạn bị ngắt hoặc re-auth; file giả MIME bị từ chối; quota chặn upload mồ côi; lịch của user mất quyền không được đăng.

