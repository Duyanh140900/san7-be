# Báo Cáo Lỗi (Bug Report) Chặng M5: Cộng Đồng (Sân 7)

- **Ngày báo cáo:** 17/11/2026 (Cập nhật kiểm thử lại sau bản sửa lỗi lúc 09:30)
- **Người báo cáo:** QA
- **Nhánh kiểm thử:** `m5-cong-dong` (`C:\source_code\sân7\san7-be`)
- **Môi trường:** Docker stack local (`san7-api-1` tại `http://localhost:3001`, `san7-worker-1`, PostgreSQL 16, Redis 7, SeaweedFS S3 tại `http://localhost:8333`) & mã nguồn Flutter (`app/lib`).

---

## Tóm tắt danh sách lỗi & mục bảo mật (C1)

| Mã Bug / Mục | Tiêu đề lỗi | Thành phần | Mức độ nghiêm trọng (Severity) | Độ ưu tiên (Priority) | Trạng thái |
|---|---|---|---|---|---|
| **BUG-M5-01** | `POST` và `PATCH /v1/teams/:teamId/post-schedules` trả lỗi HTTP `500 Internal Server Error` do `jobId` của BullMQ chứa dấu `:` | Backend (`schedules`, `jobs`) | **Nghiêm trọng (Critical / S1)** | **P0 (Sửa ngay)** | **Đã sửa** (Commit `1f93ec2` — thực tế trả `201` / `200`) |
| **BUG-M5-02** | Màn 2 (`PostCreateScreen`) chưa có giao diện chọn/tải ảnh kèm kèo (`mediaKeys`) và mục "Thời điểm đăng" (Đăng ngay / Hẹn lịch) | Frontend (`post_create_screen.dart`) | **Cao (High / S2)** | **P1** | **Đã sửa** (Commit `09d0bd5`, `829220e`) |
| **BUG-M5-03** | Chưa có endpoint `GET /v1/teams/:teamId/post-schedules` nên tab "Lịch đăng" ở Màn 10 chưa hiển thị được danh sách lịch đã hẹn | Backend + Frontend (Màn 10) | **Cao (High / S2)** | **P1** | **Đã sửa** (Commit `1f93ec2`, `43be7fc` — `GET` trả `200 OK`) |
| **BUG-M5-04** | Màn 23 (`MeScreen`) thiếu nút **"Sửa"** và màn/sheet chỉnh sửa hồ sơ cầu thủ (`PATCH /v1/me`) + chọn Khu vực mặc định | Frontend (`me_screen.dart`) | **Trung bình (Medium / S3)** | **P2** | **Đã sửa** (Commit `2f91e96`) |
| **BUG-M5-05** | Màn 21 (`ChatScreen`) chưa chuyển sang chế độ chỉ đọc (khoá ô nhập và ẩn gợi ý nhanh) khi trận đấu ở trạng thái đã huỷ (`status = cancelled`) | Frontend (`chat_screen.dart`) | **Trung bình (Medium / S3)** | **P2** | **Đã sửa** (Commit `3eb848b`) |
| **BUG-M5-06** | Lệch enum `MediaPurpose` và mã HTTP trả về khi ảnh quá 10MB trên `POST /v1/media/uploads` (`400` thay vì `413`, thiếu `receipt`) | Backend (`media.dto.ts`) | **Thấp (Low / S4)** | **P3** | **Đã sửa** (Commit `bb9b13d`, `85df12f` — quá 10MB trả `413 media_too_large`, `purpose: "receipt"` trả `201`) |
| **BUG-M5-07** | Lệch giao diện Màn 10 (`MyPostsScreen`) so với bản vẽ `san7-ui.html` (nhãn nút quay lại, nút `+` tròn góc phải, bố cục thẻ kèo) | Frontend (`my_posts_screen.dart`) | **Thấp (Low / S4)** | **P3** | **Đã sửa một phần / Còn lỗi nhỏ** (Commit `2f91e96` đã sửa `< Bảng tin` và nút `+` tròn `44×44px`; thẻ kèo vẫn dùng `SoftButton` thay vì pill xanh + link) |
| **BUG-M5-08** | Lệch giao diện Màn 21 (`ChatScreen`) so với bản vẽ `san7-ui.html` (thiếu avatar & dòng phụ đề đội trưởng trên header, trạng thái trên thẻ kèo ghim, góc nhọn bong bóng) | Frontend (`chat_screen.dart`) | **Thấp (Low / S4)** | **P3** | **Đã sửa một phần / Còn lỗi nhỏ** (Commit `3eb848b` đã sửa bong bóng góc nhọn `6px`; header vẫn chưa có avatar/phụ đề đội trưởng) |
| **BUG-M5-09** | Lệch giao diện Màn 23 (`MeScreen`) so với bản vẽ `san7-ui.html` (thiếu dòng "Tạo hoặc tham gia đội khác", thiếu icon màu mục Hoạt động, lệch nhãn công tắc thông báo) | Frontend (`me_screen.dart`) | **Thấp (Low / S4)** | **P3** | **Còn lỗi** (Visual QA mức S4) |
| **C1 (Security)** | Thu hồi kết nối Socket.IO (`evictFromTeam` + ngắt socket & hết hạn JWT) để người đã rời hoặc bị loại khỏi đội không còn nhận tin chat realtime | Backend (`realtime.gateway.ts`, `realtime.service.ts`) | **Nghiêm trọng (Critical / S1)** | **P0** | **Đã sửa** (Commit `64c04e8` — đã kiểm chứng bằng 2 client `socket.io-client`) |
| **BUG-M5-10** *(Mới)* | `GET` trực tiếp `publicUrl` (`http://localhost:8333/media/...`) từ SeaweedFS S3 không kèm chữ ký AWS trả về HTTP `403 Forbidden` (`AccessDenied`) trên container đang chạy | Backend / Hạ tầng (`media`, `storage`) | **Trung bình (Medium / S3)** | **P2** | **Còn lỗi trên container đang chạy** *(Code C7 ở commit `ad3a15d` chuyển sang `/v1/media/public/:id` đang được làm ở working tree nhưng chưa rebuild vào container)* |

---

## Kết quả kiểm thử lại 30 kịch bản API M5 & C1 Realtime (Chạy lúc 09:27 – 09:30 ngày 17/11/2026)

### 1. Bảng kết quả thực tế 30 kịch bản API M5 trên Docker (`http://localhost:3001`)

| STT | Nhóm | Phương thức & Endpoint | Kịch bản kiểm thử | Mã HTTP Mong đợi | Mã HTTP Thực tế | Mã lỗi (`code`) / Phản hồi thực tế | Kết luận |
|---|---|---|---|---|---|---|---|
| 1 | Health | `GET /v1/health` | Kiểm tra API & kết nối DB | `200` | **`200`** | `{"status":"ok","db":true}` | **PASS** |
| 2 | Hồ sơ & Thống kê | `GET /v1/me` | Không gửi Bearer token | `401` | **`401`** | `unauthorized` (`"Chưa đăng nhập"`) | **PASS** |
| 3 | Hồ sơ & Thống kê | `GET /v1/me` | Lấy hồ sơ, danh sách đội và thống kê (`matches`, `goals`, `assists`, `mvps`) | `200` | **`200`** | Trả đầy đủ `MeDto` kèm `stats: {"goals":0,"assists":0,"mvps":0,"matches":0}` | **PASS** |
| 4 | Hồ sơ & Thống kê | `PATCH /v1/me` | Cập nhật hợp lệ `name`, `position: "forward"`, `shirtNumber: 9`, `area: "Cầu Giấy"` | `200` | **`200`** | Cập nhật thành công (`position="forward"`, `shirtNumber=9`, `profileCompleted=true`) | **PASS** |
| 5 | Hồ sơ & Thống kê | `PATCH /v1/me` | Số áo vượt biên (`shirtNumber: 100`), tên rỗng `"   "`, vị trí sai enum | `400` | **`400 / 400 / 400`** | `validation_failed` (`"Dữ liệu không hợp lệ"`) | **PASS** |
| 6 | Cài đặt thông báo | `GET /v1/me/notification-settings` | Đọc cài đặt thông báo của tài khoản | `200` | **`200`** | `{"matchUpdates":true,"teamActivity":true,"community":true}` | **PASS** |
| 7 | Cài đặt thông báo | `PATCH /v1/me/notification-settings` | Tắt/bật từng nhóm thông báo (`{"community":false}`) | `200` | **`200`** | `{"matchUpdates":true,"teamActivity":true,"community":false}` | **PASS** |
| 8 | Cài đặt thông báo | `PATCH /v1/me/notification-settings` | Truyền sai kiểu dữ liệu (`{"community":"yes"}`) | `400` | **`400`** | `validation_failed` (`["community must be a boolean value"]`) | **PASS** |
| 9 | Kho ảnh (Media) | `POST /v1/media/uploads` | Xin presigned URL hợp lệ (`purpose: "post"`, `image/png`, `size: 68`) | `201` | **`201`** | Trả về `uploadUrl`, `key: "users/.../post/07240f02-....png"`, `publicUrl`, `expiresIn: 300` | **PASS** |
| 10 | Kho ảnh (S3 PUT/GET) | `PUT uploadUrl` & `GET publicUrl` | Đẩy byte ảnh thật lên SeaweedFS S3 qua `uploadUrl` rồi gọi `GET publicUrl` không chữ ký | `200 / 200` | **`200 / 403`** | `PUT uploadUrl` trả **`200 OK`**; `GET publicUrl` không chữ ký vào thẳng `:8333/media/...` trả **`403 Forbidden`** (xem **BUG-M5-10**) | **PUT PASS / GET 403 (BUG-M5-10)** |
| 11 | Kho ảnh (Media) | `POST /v1/media/uploads` | Sai định dạng file (`application/pdf`, `video/mp4`) | `415` | **`415 / 415`** | `media_type_not_allowed` (`"Chỉ nhận ảnh JPEG, PNG, WebP hoặc HEIC"`) | **PASS** |
| 12 | Kho ảnh (Media) | `POST /v1/media/uploads` | File rỗng (`size: 0`) và vượt 10MB (`size: 10485761`) (**BUG-M5-06**) | `400 / 413` | **`400 / 413`** | `size=0` → `400 validation_failed`; `size=10485761` → **`413 media_too_large`** (`"Ảnh tối đa 10MB"`) | **PASS (Đã sửa BUG-M5-06)** |
| 13 | Kho ảnh (Media) | `POST /v1/media/uploads` | Truyền `purpose: "receipt"` (**BUG-M5-06**) | `201` | **`201`** | Trả `201 Created`, `key: "users/.../receipt/f1723550-....jpg"` | **PASS (Đã sửa BUG-M5-06)** |
| 14 | Đăng kèo kèm ảnh | `POST /v1/teams/:teamId/posts` | Đăng kèo hợp lệ kèm `mediaKeys` đã upload lên S3 | `201` | **`201`** | Trả `PostDto` (`id=7ff03742-...`) có `media: [{ key, url }]` đúng ảnh đã tải lên | **PASS** |
| 15 | Đăng kèo kèm ảnh | `POST /v1/teams/:teamId/posts` | Gắn `key` ảnh thuộc user khác hoặc `key` có `purpose = avatar` | `403 / 403` | **`403 / 403`** | `media_forbidden` (`"Ảnh không thuộc về bạn"` / `"Chỉ ảnh tải lên cho kèo mới được gắn vào kèo"`) | **PASS** |
| 16 | Đăng kèo kèm ảnh | `POST /v1/teams/:teamId/posts` | Gắn `key` chưa được PUT lên kho S3 | `400` | **`400`** | `media_not_uploaded` (`"Ảnh chưa được tải lên hoặc không còn tồn tại"`) | **PASS** |
| 17 | Đăng kèo kèm ảnh | `POST /v1/teams/:teamId/posts` | Gắn quá 4 ảnh (`mediaKeys` 5 phần tử) | `400` | **`400`** | `validation_failed` (`["mediaKeys must contain no more than 4 elements"]`) | **PASS** |
| 18 | Kèo của tôi | `GET /v1/me/posts` | Lấy danh sách kèo của tôi (mặc định, lọc `status=open`, `status=matched`) | `200` | **`200 / 200 / 200`** | Trả `FeedPageDto` (`items`, `nextCursor`) kèm mảng `media` | **PASS** |
| 19 | Kèo của tôi | `GET /v1/me/posts?status=invalid` | Lọc `status` sai giá trị enum | `400` | **`400`** | `validation_failed` (`status must be one of: open, matched, closed, expired`) | **PASS** |
| 20 | Lịch đăng kèo | `POST /v1/teams/:teamId/post-schedules` | Tạo lịch đăng hợp lệ ở tương lai (`repeatWeekly: true`) (**BUG-M5-01**) | `201` | **`201`** | Trả `PostScheduleDto` (`id=02ee2ad9-a0f8-467e-9155-1ea6a274e8ba`, `status="scheduled"`, `repeatWeekly=true`) | **PASS (Đã sửa BUG-M5-01)** |
| 21 | Lịch đăng kèo | `PATCH /v1/teams/:teamId/post-schedules/:id` | Cập nhật lịch đăng đang `scheduled` (**BUG-M5-01**) | `200` | **`200`** | Trả `PostScheduleDto` đã cập nhật (`pitchName="Sân Phúc La (Đã cập nhật)"`, `repeatWeekly=false`) | **PASS (Đã sửa BUG-M5-01)** |
| 22 | Lịch đăng kèo | `DELETE /v1/teams/:teamId/post-schedules/:id` | Huỷ lịch đăng (`status = scheduled` → `cancelled`), và gọi xoá lần 2 | `204 / 404` | **`204 / 404`** | Lần 1 trả `204 No Content`; lần 2 trả `404 post_schedule_not_found` | **PASS** |
| 23 | Lịch đăng kèo | `POST /v1/teams/:teamId/post-schedules` | Tạo lịch đăng với `scheduledAt` ở quá khứ / Thành viên thường gọi tạo lịch | `400 / 403` | **`400 / 403`** | Quá khứ trả `400 schedule_in_past`; thành viên thường trả `403 team_role_required` | **PASS** |
| 24 | Lịch đăng kèo | `GET /v1/teams/:teamId/post-schedules` | Lấy danh sách lịch đăng đã hẹn của đội (**BUG-M5-03**) | `200` | **`200`** | Trả mảng `PostScheduleDto[]` sắp xếp theo `scheduledAt ASC` | **PASS (Đã sửa BUG-M5-03)** |
| 25 | Chat hai đội | `GET /v1/matches/:id/messages` | Thành viên `active` lấy lịch sử tin nhắn & phân trang `limit`, `cursor` | `200` | **`200`** | Trả `MessagePageDto` (`items`, `nextCursor`) mới nhất trước | **PASS** |
| 26 | Chat hai đội | `POST /v1/matches/:id/messages` | Thành viên `active` gửi tin nhắn hợp lệ (có khoảng trắng ở 2 đầu) | `201` | **`201`** | Tự động trim khoảng trắng, lưu DB và phát sự kiện Socket.IO `chat.message` | **PASS** |
| 27 | Chat hai đội | `POST /v1/matches/:id/messages` | Gửi tin nhắn rỗng `"   "` hoặc dài `> 1000` ký tự | `400` | **`400 / 400`** | `validation_failed` (`body` từ 1 đến 1000 ký tự) | **PASS** |
| 28 | Chat hai đội | `GET` & `POST /v1/matches/:id/messages` | Người ngoài hai đội truy cập xem hoặc gửi tin nhắn | `403 / 403` | **`403 / 403`** | `chat_forbidden` (`"Chỉ thành viên hai đội mới xem được trao đổi của trận này"`) | **PASS** |
| 29 | Chat hai đội | `GET` & `POST /v1/matches/:id/messages` | Trận đấu đã huỷ (`status = cancelled`): xem lịch sử vs gửi tin mới | `200 / 409` | **`200 / 409`** | `GET` trả `200 OK` (chỉ đọc); `POST` trả `409 Conflict` (`match_cancelled`: `"Trận đã huỷ, không thể gửi tin nhắn"`) | **PASS** |
| 30 | Chat hai đội | `GET /v1/matches/:id/messages` | `matchId` sai định dạng UUID hoặc UUID không tồn tại | `400 / 404` | **`400 / 404`** | Sai UUID trả `400 bad_request`; không tồn tại trả `404 match_not_found` | **PASS** |

---

### 2. Kết quả kiểm thử C1 (Socket.IO Realtime — Thu hồi quyền nhận tin chat khi rời / bị loại khỏi đội)

Đã kiểm thử thực tế với 2 user kết nối WebSocket (`path: '/v1/socket'`) tới `http://localhost:3001`:
- **Kịch bản C1-1 (Đội trưởng loại thành viên khỏi đội — `DELETE /v1/teams/:teamId/members/:userId`):**
  1. `User A` (đội chủ nhà `Beer Family Fc`) và `User C` (thành viên `active` của đội khách `FC Mỹ Đình`) cùng mở kết nối Socket.IO và gửi `match:join` (`{ matchId: "00000000-0000-4000-8000-0000000000c1" }`) → cả hai nhận ack `{ ok: true }`.
  2. `User A` gửi tin nhắn 1 (`POST /v1/matches/:id/messages` → HTTP `201`) → cả `User A` và `User C` đều nhận được sự kiện `chat.message` realtime (`receivedA = 1`, `receivedC = 1`).
  3. Đội trưởng `User B` gọi `DELETE /v1/teams/:teamId/members/:userC` → trả về HTTP **`204 No Content`**. Ngay lập tức `RealtimeService.evictFromTeam` ngắt kết nối socket của `User C` (`socketC.connected === false`, sự kiện `disconnect` được kích hoạt).
  4. `User A` gửi tin nhắn 2 (`POST /v1/matches/:id/messages` → HTTP `201`) → `User A` nhận được (`receivedA = 2`), còn `User C` **không nhận được** (`receivedC` giữ nguyên `1`).
  5. `User C` dùng lại access token cũ (vẫn còn hạn) kết nối lại Socket.IO và phát `match:join` / `team:join` → Server từ chối với ack `{ ok: false }` cho cả 2 sự kiện; khi `User A` gửi tin nhắn 3 (HTTP `201`), socket mới của `User C` nhận `0` tin nhắn.
- **Kịch bản C1-2 (Thành viên tự rời đội — `DELETE /v1/teams/:teamId/members/me`):**
  1. `User C` (đang là `member` `active` của `FC Mỹ Đình`) kết nối Socket.IO và `match:join` thành công (`{ ok: true }`).
  2. `User C` gọi `DELETE /v1/teams/:teamId/members/me` → trả về HTTP **`204 No Content`**. Socket của `User C` bị server ngắt ngay lập tức (`disconnected = true`).
  3. `User A` gửi tin nhắn 4 (`POST /v1/matches/:id/messages` → HTTP `201`) → `User C` không nhận được tin nhắn nào (`receivedC3 = 0`).
- **Kịch bản C1-3 (Access token hết hạn khi đang giữ kết nối Socket.IO):**
  1. Kết nối Socket.IO với JWT có `exp` sau 2 giây.
  2. Đúng thời điểm hết hạn, server bắn sự kiện `auth:error` với payload `{"code":"token_expired"}` và chủ động ngắt kết nối (`disconnected = true`).
- **Kết luận C1:** **ĐÃ SỬA (PASS)**.

---

## Chi tiết từng lỗi & lịch sử xác minh

### BUG-M5-01: `POST` và `PATCH /v1/teams/:teamId/post-schedules` trả lỗi HTTP `500 Internal Server Error` do `jobId` của BullMQ chứa dấu `:`
- **Trạng thái:** **Đã sửa** *(Commit `1f93ec2`)*
- **Mức độ nghiêm trọng (Severity):** Nghiêm trọng (Critical / S1)
- **Độ ưu tiên (Priority):** P0
- **Vị trí code:** `backend/src/schedules/schedules.service.ts`, `backend/src/jobs/system.processor.ts`
- **Kết quả kiểm thử lại (17/11/2026 09:27):**
  - Đã đổi hàm sinh `jobId` sang `postScheduleJobId(id, scheduledAt) = "post-schedule-${id}-${scheduledAt.getTime()}"` (không chứa dấu `:`).
  - `POST /v1/teams/00000000-0000-4000-8000-0000000000b1/post-schedules` trả về HTTP **`201 Created`** (`id: "02ee2ad9-a0f8-467e-9155-1ea6a274e8ba"`, `status: "scheduled"`, `repeatWeekly: true`).
  - `PATCH /v1/teams/00000000-0000-4000-8000-0000000000b1/post-schedules/02ee2ad9-a0f8-467e-9155-1ea6a274e8ba` trả về HTTP **`200 OK`** (`pitchName: "Sân Phúc La (Đã cập nhật)"`, `repeatWeekly: false`).

---

### BUG-M5-02: Màn 2 (`PostCreateScreen`) chưa có giao diện chọn/tải ảnh kèm kèo (`mediaKeys`) và mục "Thời điểm đăng" (Đăng ngay / Hẹn lịch)
- **Trạng thái:** **Đã sửa** *(Commit `09d0bd5` & `829220e`)*
- **Mức độ nghiêm trọng (Severity):** Cao (High / S2)
- **Độ ưu tiên (Priority):** P1
- **Vị trí code:** `app/lib/features/post_create/presentation/post_create_screen.dart`
- **Kết quả kiểm thử lại:**
  - `post_create_screen.dart` đã bổ sung chọn ảnh (`PostImagePicker`), tải lên S3 qua `uploadPostImage` lấy `mediaKeys`, và thêm mục **"Thời điểm đăng"** (`Segmented` `['Đăng ngay', 'Hẹn lịch']`, chọn ngày/giờ đăng, công tắc `Lặp lại hàng tuần`) gọi `createSchedule`.

---

### BUG-M5-03: Chưa có endpoint `GET` danh sách lịch đăng kèo nên tab "Lịch đăng" ở Màn 10 chỉ hiện thông báo chờ máy chủ
- **Trạng thái:** **Đã sửa** *(Commit `1f93ec2` & `43be7fc`)*
- **Mức độ nghiêm trọng (Severity):** Cao (High / S2)
- **Độ ưu tiên (Priority):** P1
- **Vị trí code:**
  - Backend: `backend/src/schedules/schedules.controller.ts` (`@Get()`), `backend/src/schedules/schedules.service.ts` (`list(me)`).
  - Frontend: `app/lib/features/me/presentation/post_schedules_tab.dart`.
- **Kết quả kiểm thử lại (17/11/2026 09:27):**
  - `GET http://localhost:3001/v1/teams/00000000-0000-4000-8000-0000000000b1/post-schedules` trả về HTTP **`200 OK`** kèm mảng `PostScheduleDto[]` sắp xếp theo `scheduledAt ASC`.
  - Màn 10 (`MyPostsScreen`) đã nhúng `PostSchedulesTab` hiển thị danh sách lịch đang chờ đăng (`ScheduleCard`) kèm nút **"Huỷ lịch"** có hộp thoại xác nhận.

---

### BUG-M5-04: Màn 23 (`MeScreen`) thiếu nút "Sửa" để cập nhật hồ sơ cầu thủ (`PATCH /v1/me`) và dòng "Khu vực" chưa bấm chọn được
- **Trạng thái:** **Đã sửa** *(Commit `2f91e96`)*
- **Mức độ nghiêm trọng (Severity):** Trung bình (Medium / S3)
- **Độ ưu tiên (Priority):** P2
- **Vị trí code:** `app/lib/features/me/presentation/me_screen.dart`
- **Kết quả kiểm thử lại:**
  - `DetailHeader` trên `MeScreen` đã gắn `trailing: LinkButton('Sửa', onTap: () => context.push(Routes.editProfile))` và dòng `MeRow(title: 'Khu vực', ...)` đã gắn `onTap: () => context.push(Routes.editProfile)`.

---

### BUG-M5-05: Màn 21 (`ChatScreen`) chưa khoá ô nhập tin nhắn và chip gợi ý nhanh khi trận đấu ở trạng thái đã huỷ (`status = cancelled`)
- **Trạng thái:** **Đã sửa** *(Commit `3eb848b`)*
- **Mức độ nghiêm trọng (Severity):** Trung bình (Medium / S3)
- **Độ ưu tiên (Priority):** P2
- **Vị trí code:** `app/lib/features/chat/presentation/chat_screen.dart`
- **Kết quả kiểm thử lại:**
  - Khi `m?.status == MatchStatus.cancelled`, `ChatScreen` đã ẩn `_QuickReplies` + `_Composer` và hiển thị thanh thông báo chỉ đọc `_CancelledBar` (`"Trận đã huỷ, chỉ đọc được tin nhắn cũ"`).
  - Trên API, `GET /v1/matches/:id/messages` cho trận đã huỷ trả về HTTP **`200 OK`**, còn `POST /v1/matches/:id/messages` trả về HTTP **`409 Conflict`** (`code: "match_cancelled"`).

---

### BUG-M5-06: `POST /v1/media/uploads` trả về HTTP `400` thay vì `413` khi file vượt quá 10MB và enum `MediaPurpose` chưa khớp tài liệu BA
- **Trạng thái:** **Đã sửa** *(Commit `bb9b13d` & `85df12f`)*
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `backend/src/media/media.dto.ts` & `backend/src/media/media.service.ts`
- **Kết quả kiểm thử lại (17/11/2026 09:27):**
  - Gửi `POST /v1/media/uploads` với `{ "purpose": "post", "contentType": "image/jpeg", "size": 10485761 }` (`10MB + 1 byte`) trả về HTTP **`413 Payload Too Large`** với body `{"statusCode":413,"code":"media_too_large","message":"Ảnh tối đa 10MB"}`.
  - Gửi `POST /v1/media/uploads` với `{ "purpose": "receipt", "contentType": "image/jpeg", "size": 1000 }` trả về HTTP **`201 Created`** với `key: "users/.../receipt/f1723550-3b7c-4699-908e-0cb8fc2f074a.jpg"`.

---

### BUG-M5-07: Lệch giao diện Màn 10 (`MyPostsScreen`) so với bản vẽ `san7-ui.html`
- **Trạng thái:** **Đã sửa một phần / Còn lỗi nhỏ** *(Commit `2f91e96`)*
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/me/presentation/my_posts_screen.dart`
- **Chi tiết trạng thái:**
  1. **Thanh điều hướng trên cùng (Đã sửa ở commit `2f91e96`):** Nút quay lại đã đổi thành `< Bảng tin`, góc phải đã đổi thành nút tròn trắng `44×44px` (`AppSizes.tapTarget`) chứa icon dấu cộng `+` (`Semantics(label: 'Đăng kèo mới')`).
  2. **Thẻ kèo ở tab Đang mở & Đã chốt (Còn lệch nhẹ):** `_MyPostCard` vẫn hiển thị dòng phụ chỉ gồm `pitchName · area` (chưa hiện trình độ & tỷ lệ kèo) và dùng `SoftButton` trải rộng `"N đội muốn nhận · So sánh"` thay vì huy hiệu pill xanh `#0066CC` ở góc phải trên + link `"So sánh & chọn đội"`.

---

### BUG-M5-08: Lệch giao diện Màn 21 (`ChatScreen`) so với bản vẽ `san7-ui.html`
- **Trạng thái:** **Đã sửa một phần / Còn lỗi nhỏ** *(Commit `3eb848b` & `d9baa48`)*
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/chat/presentation/chat_screen.dart`
- **Chi tiết trạng thái:**
  1. **Kiểu dáng bong bóng chat (Đã sửa ở commit `3eb848b`):** Bong bóng chat đã có góc nhọn `6px` ở phía người gửi (`borderRadius` `18/18/6/18` cho tin gửi đi, `18/18/18/6` cho tin nhận về) đúng bản vẽ.
  2. **Header màn Chat & Thẻ kèo ghim (Còn lệch nhẹ):** Header vẫn dùng `DetailHeader` chữ đơn giản (chưa có cụm Avatar đội đối thủ, dòng phụ đề tên đội trưởng, nút gọi điện); thẻ `_PinnedMatch` chưa có pill nhãn `"Kèo"` và trạng thái trận.

---

### BUG-M5-09: Lệch giao diện Màn 23 (`MeScreen`) so với bản vẽ `san7-ui.html`
- **Trạng thái:** **Còn lỗi** *(Visual QA mức S4)*
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/me/presentation/me_screen.dart`
- **Các điểm lệch quan sát được:**
  1. **Nhóm "Đội của tôi":** Cuối danh sách đội chưa có dòng hành động màu xanh `#0066CC`: `"Tạo hoặc tham gia đội khác"`.
  2. **Nhóm "Hoạt động":** Các dòng trong nhóm **Hoạt động** chưa có biểu tượng nền màu bo góc `8px` (`30×30px`) ở `leading` và chưa có 2 mục lối tắt `Lịch sử đặt sân`, `Quỹ của tôi`.
  3. **Thẻ Hồ sơ cầu thủ (`_Profile`):** Đang bọc trong `AppCard` nền trắng (Avatar `64×64px`) thay vì hiển thị trực tiếp trên nền `#F5F5F7` (Avatar `76×76px`).

---

### BUG-M5-10 *(Mới)*: `GET` trực tiếp `publicUrl` (`http://localhost:8333/media/...`) từ SeaweedFS S3 không kèm chữ ký trả về HTTP `403 Forbidden` trên container đang chạy
- **Trạng thái:** **Còn lỗi trên container đang chạy** *(Đang được xử lý ở nhánh C7 `ad3a15d` nhưng chưa rebuild vào container)*
- **Mức độ nghiêm trọng (Severity):** Trung bình (Medium / S3)
- **Độ ưu tiên (Priority):** P2
- **Vị trí code:** `backend/src/media/media.service.ts` (trên container `san7-api-1` đang chạy) & cấu hình `storage` trong `docker-compose.yml`
- **Các bước tái hiện (Steps to Reproduce):**
  1. Gọi `POST http://localhost:3001/v1/media/uploads` với `{ "purpose": "post", "contentType": "image/png", "size": 68 }` → nhận `201 Created` kèm `uploadUrl` và `publicUrl: "http://localhost:8333/media/users/.../post/07240f02-bae3-4e73-a9e8-6b8c97931f65.png"`.
  2. Dùng HTTP `PUT` đẩy 68 bytes ảnh PNG lên `uploadUrl` với đúng header `Content-Type: image/png` và `Content-Length: 68` → SeaweedFS trả về HTTP **`200 OK`**.
  3. Gọi `GET` trực tiếp vào `publicUrl` (không đính kèm chữ ký S3, giống như khi thẻ `<img src>` hoặc `Image.network` trên app tải ảnh):
     ```text
     GET http://localhost:8333/media/users/39ec6703-8953-4c8c-bf2c-d136f3b91f36/post/07240f02-bae3-4e73-a9e8-6b8c97931f65.png
     ```
- **Kết quả mong đợi (Expected Result):**
  - URL công khai của ảnh đã duyệt/tải lên (`publicUrl` hoặc `/v1/media/public/:id`) phải trả về HTTP `200 OK` kèm nội dung ảnh để ứng dụng hiển thị được trên Bảng tin và Chi tiết kèo.
- **Kết quả thực tế (Actual Result):**
  - SeaweedFS S3 (khi chạy với `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` mà chưa cấu hình anonymous read hoặc chưa đi qua endpoint proxy `/v1/media/public/:id`) trả về HTTP **`403 Forbidden`** (`application/xml` — `AccessDenied`).
  - *Ghi chú:* Commit `ad3a15d` (`feat(media): quarantine upload, xử lý lại bằng Sharp, quota và dọn dẹp (C7)`) đã chuyển `publicUrl` sang phục vụ qua API `GET /v1/media/public/:id`, nhưng bản build trong container `san7-api-1` hiện tại chưa có commit này (và theo yêu cầu không rebuild Docker trong lượt kiểm thử này). Cần rebuild image `san7-backend:local` sau khi hoàn tất working tree của `media.service.ts` rồi kiểm thử lại kịch bản #10.
