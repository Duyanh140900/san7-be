# Báo Cáo Lỗi (Bug Report) Chặng M5: Cộng Đồng (Sân 7)

- **Ngày báo cáo:** 17/11/2026
- **Người báo cáo:** QA
- **Nhánh kiểm thử:** `m5-cong-dong` (`C:\source_code\sân7\san7-be`)
- **Môi trường:** Docker stack local (`san7-api-1` tại `http://localhost:3001`, PostgreSQL 16, Redis 7, SeaweedFS S3 tại `http://localhost:8333`) & mã nguồn Flutter (`app/lib`).

---

## Tóm tắt danh sách lỗi

| Mã Bug | Tiêu đề lỗi | Thành phần | Mức độ nghiêm trọng (Severity) | Độ ưu tiên (Priority) | Trạng thái |
|---|---|---|---|---|---|
| **BUG-M5-01** | `POST` và `PATCH /v1/teams/:teamId/post-schedules` trả lỗi HTTP `500 Internal Server Error` do `jobId` của BullMQ chứa dấu `:` | Backend (`schedules`, `jobs`) | **Nghiêm trọng (Critical / S1)** | **P0 (Sửa ngay)** | Open |
| **BUG-M5-02** | Màn 2 (`PostCreateScreen`) chưa có giao diện chọn/tải ảnh kèm kèo (`mediaKeys`) và mục "Thời điểm đăng" (Đăng ngay / Hẹn lịch) | Frontend (`post_create_screen.dart`) | **Cao (High / S2)** | **P1** | Open |
| **BUG-M5-03** | Chưa có endpoint `GET /v1/teams/:teamId/post-schedules` (hoặc `/v1/me/post-schedules`) nên tab "Lịch đăng" ở Màn 10 chưa hiển thị được danh sách lịch đã hẹn | Backend + Frontend (Màn 10) | **Cao (High / S2)** | **P1** | Open |
| **BUG-M5-04** | Màn 23 (`MeScreen`) thiếu nút **"Sửa"** và màn/sheet chỉnh sửa hồ sơ cầu thủ (`PATCH /v1/me`) + chọn Khu vực mặc định | Frontend (`me_screen.dart`) | **Trung bình (Medium / S3)** | **P2** | Open |
| **BUG-M5-05** | Màn 21 (`ChatScreen`) chưa chuyển sang chế độ chỉ đọc (khoá ô nhập và ẩn gợi ý nhanh) khi trận đấu ở trạng thái đã huỷ (`status = cancelled`) | Frontend (`chat_screen.dart`) | **Trung bình (Medium / S3)** | **P2** | Open |
| **BUG-M5-06** | Lệch enum `MediaPurpose` và mã HTTP trả về khi ảnh quá 10MB trên `POST /v1/media/uploads` (`400` thay vì `413`, thiếu `receipt`) | Backend (`media.dto.ts`) | **Thấp (Low / S4)** | **P3** | Open |
| **BUG-M5-07** | Lệch giao diện Màn 10 (`MyPostsScreen`) so với bản vẽ `san7-ui.html` (nhãn nút quay lại, nút `+` góc phải, số đếm trên tab) | Frontend (`my_posts_screen.dart`) | **Thấp (Low / S4)** | **P3** | Open |
| **BUG-M5-08** | Lệch giao diện Màn 21 (`ChatScreen`) so với bản vẽ `san7-ui.html` (thiếu avatar & dòng phụ đề đội trưởng trên header, trạng thái trên thẻ kèo ghim) | Frontend (`chat_screen.dart`) | **Thấp (Low / S4)** | **P3** | Open |
| **BUG-M5-09** | Lệch giao diện Màn 23 (`MeScreen`) so với bản vẽ `san7-ui.html` (thiếu dòng "Tạo hoặc tham gia đội khác", thiếu icon màu mục Hoạt động, lệch nhãn công tắc thông báo) | Frontend (`me_screen.dart`) | **Thấp (Low / S4)** | **P3** | Open |

---

## Chi tiết từng lỗi

### BUG-M5-01: `POST` và `PATCH /v1/teams/:teamId/post-schedules` trả lỗi HTTP `500 Internal Server Error` do `jobId` của BullMQ chứa dấu `:`
- **Mức độ nghiêm trọng (Severity):** Nghiêm trọng (Critical / S1) — Hỏng hoàn toàn luồng tạo và cập nhật lịch hẹn đăng kèo trên môi trường chạy thật với Redis/BullMQ.
- **Độ ưu tiên (Priority):** P0
- **Vị trí code:**
  - `backend/src/schedules/schedules.service.ts` (dòng 114, 121, 142): dùng `post-schedule:${id}`
  - `backend/src/jobs/system.processor.ts` (dòng 71): dùng `jobId: "post-schedule:${scheduleId}"`
  - *(Trong khi các service khác như `bookings.service.ts` dòng 493 và `requests.service.ts` dòng 553, 572 đều dùng dấu gạch ngang `-` như `booking-expire-${id}`, `match-prompt-${matchId}`).*
- **Các bước tái hiện (Steps to Reproduce):**
  1. Gửi request `POST http://localhost:3001/v1/teams/00000000-0000-4000-8000-0000000000b1/post-schedules` với Bearer token của `captain` và body hợp lệ:
     ```json
     {
       "type": "find_opponent",
       "startAt": "2026-11-22T12:00:00.000Z",
       "endAt": "2026-11-22T13:30:00.000Z",
       "pitchName": "Sân Phúc La",
       "level": "tb",
       "deal": "split",
       "ratioWin": 40,
       "ratioLose": 60,
       "scheduledAt": "2026-11-18T02:00:00.000Z",
       "repeatWeekly": true
     }
     ```
  2. Quan sát phản hồi HTTP và log của container `san7-api-1`.
- **Kết quả mong đợi (Expected Result):**
  - API trả về HTTP `201 Created` (khi `POST`) hoặc `200 OK` (khi `PATCH`) kèm `PostScheduleDto`, và tạo job thành công trong hàng đợi BullMQ.
- **Kết quả thực tế (Actual Result):**
  - API trả về HTTP `500 Internal Server Error`: `{"statusCode":500,"code":"internal_error","message":"Có lỗi xảy ra, thử lại sau"}`.
  - Bản ghi `post_schedules` đã được `INSERT` vào PostgreSQL nhưng bước `this.enqueue(row.id, row.scheduledAt)` thất bại vì BullMQ v5 cấm ký tự `:` trong custom `jobId`:
    ```text
    Error: Custom Id cannot contain :
        at Job.validateOptions (/app/node_modules/bullmq/dist/cjs/classes/job.js:918:23)
        at PostSchedulesService.enqueue (file:///app/dist/schedules/schedules.service.js:135:27)
        at PostSchedulesService.create (file:///app/dist/schedules/schedules.service.js:103:20)
    ```
- **Hướng khắc phục đề xuất:** Đổi `post-schedule:${id}` thành `post-schedule-${id}` tại `schedules.service.ts`, `system.processor.ts` và cập nhật lại `schedules.service.spec.ts`.

---

### BUG-M5-02: Màn 2 (`PostCreateScreen`) chưa có giao diện chọn/tải ảnh kèm kèo (`mediaKeys`) và mục "Thời điểm đăng" (Đăng ngay / Hẹn lịch)
- **Mức độ nghiêm trọng (Severity):** Cao (High / S2)
- **Độ ưu tiên (Priority):** P1
- **Vị trí code:** `app/lib/features/post_create/presentation/post_create_screen.dart`
- **Các bước tái hiện (Steps to Reproduce):**
  1. Mở Màn 2 (**Đăng kèo** — `PostCreateScreen`).
  2. Cuộn kiểm tra toàn bộ các trường trên biểu mẫu và đối chiếu với bản vẽ `docs/design/san7-ui.html` (Màn 2) cũng như tiêu chí nghiệm thu `US-M5-01` và `US-M5-05`.
- **Kết quả mong đợi (Expected Result):**
  - Có mục **"Ảnh & video"** cho phép chọn ảnh từ máy, gọi `POST /v1/media/uploads` + `PUT` lên S3 và gửi mảng `mediaKeys` vào `CreatePostDto` khi bấm **Đăng**.
  - Có mục **"Thời điểm đăng"** (`Đăng ngay` | `Hẹn lịch`, chọn giờ đăng, bật `Lặp lại hàng tuần`) gọi `POST /v1/teams/:teamId/post-schedules`.
- **Kết quả thực tế (Actual Result):**
  - `post_create_screen.dart` mới chỉ gửi `CreatePostDto` không có `mediaKeys` và chưa có UI chọn ảnh hay UI hẹn lịch đăng (comment đầu file vẫn ghi: `/// Màn 2 · Đăng kèo: tìm đối, tuyển người, pass sân. Hẹn lịch và ảnh/video có ở M5.`).

---

### BUG-M5-03: Chưa có endpoint `GET` danh sách lịch đăng kèo nên tab "Lịch đăng" ở Màn 10 chỉ hiện thông báo chờ máy chủ
- **Mức độ nghiêm trọng (Severity):** Cao (High / S2)
- **Độ ưu tiên (Priority):** P1
- **Vị trí code:**
  - Backend: `backend/src/schedules/schedules.controller.ts` (chỉ có `@Post()`, `@Patch(':scheduleId')`, `@Delete(':scheduleId')`).
  - Frontend: `app/lib/features/me/presentation/my_posts_screen.dart` (`_SchedulesInfo`).
- **Các bước tái hiện (Steps to Reproduce):**
  1. Gọi `GET http://localhost:3001/v1/teams/00000000-0000-4000-8000-0000000000b1/post-schedules`.
  2. Mở Màn 10 (**Kèo của tôi**) trên app và bấm sang tab thứ 2 (**"Lịch đăng"**).
- **Kết quả mong đợi (Expected Result):**
  - Theo bản vẽ Màn 10 (`san7-ui.html`), tab **"Lịch đăng"** hiển thị danh sách các lịch hẹn đăng kèo của đội kèm trạng thái (`Đang chạy` / `Đã tạm dừng`), các thứ trong tuần, giờ đăng và nút thao tác **Sửa / Tạm dừng / Xoá**.
- **Kết quả thực tế (Actual Result):**
  - Endpoint `GET /v1/teams/:teamId/post-schedules` trả về HTTP `404 Not Found` (`Cannot GET ...`).
  - Trên UI Màn 10, tab **Lịch đăng** hiện chỉ hiển thị thẻ tĩnh: `"Danh sách lịch đăng sẽ hiện ở đây khi máy chủ hỗ trợ xem lịch đã hẹn."`.

---

### BUG-M5-04: Màn 23 (`MeScreen`) thiếu nút "Sửa" để cập nhật hồ sơ cầu thủ (`PATCH /v1/me`) và dòng "Khu vực" chưa bấm chọn được
- **Mức độ nghiêm trọng (Severity):** Trung bình (Medium / S3)
- **Độ ưu tiên (Priority):** P2
- **Vị trí code:** `app/lib/features/me/presentation/me_screen.dart` (dòng 35, 73, 107–133)
- **Các bước tái hiện (Steps to Reproduce):**
  1. Mở Màn 23 (**Cá nhân & cài đặt** — `MeScreen`).
  2. Quan sát góc phải trên của thanh tiêu đề (`DetailHeader(backLabel: 'Bảng tin')`), thẻ hồ sơ `_Profile` và dòng `MeRow(title: 'Khu vực', value: me.area ?? 'Chưa chọn')`.
- **Kết quả mong đợi (Expected Result):**
  - Theo bản vẽ Màn 23 (`san7-ui.html`) và tiêu chí nghiệm thu `AC4.2` (`docs/stories/m5-acceptance.md`), góc phải thanh tiêu đề (hoặc trên thẻ hồ sơ) có nút **"Sửa"** (`min-height: 44px`), khi bấm cho phép sửa Tên, Vị trí, Số áo (0–99), Khu vực và gọi `PATCH /v1/me` (hàm `MeRepository.updateMe` đã được viết trong `me_repository.dart` nhưng chưa được gắn vào UI).
- **Kết quả thực tế (Actual Result):**
  - `DetailHeader(backLabel: 'Bảng tin')` không truyền `trailing`, và dòng `MeRow(title: 'Khu vực', ...)` không truyền `onTap`, dẫn tới người dùng không có cách nào chỉnh sửa hồ sơ hoặc đổi khu vực mặc định trên Màn 23 (`MeRepository.updateMe` hiện không được gọi ở đâu trong `app/lib`).

---

### BUG-M5-05: Màn 21 (`ChatScreen`) chưa khoá ô nhập tin nhắn và chip gợi ý nhanh khi trận đấu ở trạng thái đã huỷ (`status = cancelled`)
- **Mức độ nghiêm trọng (Severity):** Trung bình (Medium / S3)
- **Độ ưu tiên (Priority):** P2
- **Vị trí code:** `app/lib/features/chat/presentation/chat_screen.dart` (dòng 162–168)
- **Các bước tái hiện (Steps to Reproduce):**
  1. Mở Màn 21 (`ChatScreen`) của một trận đấu có `match.status == MatchStatus.cancelled`.
  2. Quan sát thanh chip gợi ý nhanh (`_QuickReplies`) và thanh nhập tin nhắn (`_Composer`) ở cuối màn hình.
- **Kết quả mong đợi (Expected Result):**
  - Theo yêu cầu nghiệp vụ ("trận huỷ chỉ đọc"), khi `m?.status == MatchStatus.cancelled`, giao diện ẩn hoặc vô hiệu hoá (`disabled`) thanh gợi ý nhanh và ô nhập tin nhắn, hiển thị dòng thông báo `"Trận đấu đã huỷ — chỉ có thể xem lại tin nhắn cũ"`.
- **Kết quả thực tế (Actual Result):**
  - Giao diện vẫn hiển thị bình thường cả 3 chip gợi ý nhanh và ô nhập tin nhắn; chỉ sau khi người dùng gõ và bấm gửi thì API mới trả lỗi `409 match_cancelled` và hiện toast lỗi.

---

### BUG-M5-06: `POST /v1/media/uploads` trả về HTTP `400` thay vì `413` khi file vượt quá 10MB và enum `MediaPurpose` chưa khớp tài liệu BA
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `backend/src/media/media.dto.ts` (dòng 15–19, 39) & `backend/src/media/media.service.ts` (dòng 94–100)
- **Các bước tái hiện (Steps to Reproduce):**
  1. Gửi `POST /v1/media/uploads` với `{ "purpose": "post", "contentType": "image/jpeg", "size": 10485761 }` (`10MB + 1 byte`).
  2. Gửi `POST /v1/media/uploads` với `{ "purpose": "receipt", "contentType": "image/jpeg", "size": 1000 }` (để tải ảnh hoá đơn quỹ theo `US-M5-05`).
- **Kết quả mong đợi (Expected Result):**
  - Theo doc comment ở `media.controller.ts` (`Lỗi: 413 media_too_large, 415 media_type_not_allowed, 503 storage_unavailable`) và `AC5.3` trong `m5-acceptance.md`, khi `size > 10MB` API trả về HTTP `413 Payload Too Large` (`code: "media_too_large"`).
  - Enum `MediaPurpose` thống nhất giữa tài liệu BA (`post | avatar | receipt`) và code Backend (`post | avatar | team`).
- **Kết quả thực tế (Actual Result):**
  - Do `CreateUploadDto.size` gắn decorator `@Max(MAX_IMAGE_BYTES)` của `class-validator`, `ValidationPipe` chặn trước khi vào `MediaService.createImageUpload` và trả về HTTP `400 Bad Request` (`code: "validation_failed"`) thay vì `413 Payload Too Large` (`code: "media_too_large"`).
  - Truyền `purpose: "receipt"` bị từ chối với HTTP `400` vì enum `MediaPurpose` trong code chỉ có `post`, `avatar`, `team`.

---

### BUG-M5-07: Lệch giao diện Màn 10 (`MyPostsScreen`) so với bản vẽ `san7-ui.html`
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/me/presentation/my_posts_screen.dart` (dòng 35–42, 121–162)
- **Các điểm lệch quan sát được:**
  1. **Thanh điều hướng trên cùng:**
     - **Mong đợi (Bản vẽ Màn 10):** Nút quay lại ghi `< Bảng tin`, góc phải là nút tròn trắng `40×40px` (`border-radius: 999px`) chứa icon dấu cộng `+` (`aria-label="Đăng kèo mới"`).
     - **Thực tế (`my_posts_screen.dart`):** Nút quay lại ghi `< Cá nhân`, góc phải dùng `TextButton` chữ `"Đăng kèo mới"`.
  2. **Thẻ kèo ở tab Đang mở & Đã chốt:**
     - **Mong đợi (Bản vẽ Màn 10):** Thẻ kèo hiển thị tiêu đề bài kèo (`17px, w600`), dòng thông tin phụ có trình độ & tỷ lệ (`T7 22/11 · 19:00 · Phúc La · TB · 40–60`), huy hiệu `"3 đội muốn nhận"` màu xanh `#0066CC` chữ trắng nằm ngang hàng với badge loại kèo ở góc phải trên, và dòng link `"So sánh & chọn đội"` ở dưới.
     - **Thực tế (`_MyPostCard`):** Hiển thị giờ đá cạnh badge loại kèo, dòng dưới chỉ có `pitchName · area` (thiếu trình độ và tỷ lệ kèo), và dùng `SoftButton` trải rộng `"3 đội muốn nhận · So sánh"`.

---

### BUG-M5-08: Lệch giao diện Màn 21 (`ChatScreen`) so với bản vẽ `san7-ui.html`
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/chat/presentation/chat_screen.dart` (dòng 162–168, 198–218, 275–297)
- **Các điểm lệch quan sát được:**
  1. **Header màn Chat:**
     - **Mong đợi (Bản vẽ Màn 21):** Hiển thị cụm Avatar tròn của đội đối thủ (`38×38px`, bấm vào mở Hồ sơ đội Màn 22), tên đội (`16px, w600`) kèm dòng phụ đề `"Tiến Linh · đội trưởng · đang hoạt động"` (`12px, #6E6E73`), và nút tròn icon **Gọi điện** (`40×40px`) ở góc phải.
     - **Thực tế (`chat_screen.dart`):** Dùng `DetailHeader(backLabel: 'Lịch', title: opponent?.name ?? 'Nhắn tin')` chỉ có chữ tiêu đề ở giữa, không có avatar đội, dòng phụ đề hay nút gọi/xem hồ sơ đội.
  2. **Thẻ kèo ghim đầu màn (`_PinnedMatch`):**
     - **Mong đợi (Bản vẽ Màn 21):** Có pill nhãn `"Kèo"` (`#E8F0FB`, chữ `#0058B0`) bên trái, thông tin giờ · sân · tỷ lệ ở giữa, và trạng thái trận ở bên phải; bấm vào mở Chi tiết kèo (Màn 14).
     - **Thực tế (`_PinnedMatch`):** Chỉ hiện một dòng `Text` đơn giản, không có pill nhãn `"Kèo"`, không hiện trạng thái trận và chưa bấm vào được.
  3. **Kiểu dáng bong bóng chat và chip gợi ý nhanh:**
     - **Mong đợi (Bản vẽ Màn 21):** Bong bóng chat có góc nhọn ở phía người gửi (`border-radius: 18px 18px 6px 18px` cho tin gửi đi, `18px 18px 18px 6px` cho tin nhận về); chip gợi ý nhanh nền trắng `#FFFFFF`, viền `#D2D2D7`, chữ `#0066CC`; ô nhập tin nhắn bo tròn dạng pill (`border-radius: 999px`, nền `#F5F5F7`) đặt trong thanh đáy nền trắng.
     - **Thực tế (`chat_screen.dart`):** Bong bóng bo đều 4 góc `18px`; chip gợi ý nhanh dùng nền xanh nhạt `AppColors.primarySoft` không viền.

---

### BUG-M5-09: Lệch giao diện Màn 23 (`MeScreen`) so với bản vẽ `san7-ui.html`
- **Mức độ nghiêm trọng (Severity):** Thấp (Low / S4 — Visual QA)
- **Độ ưu tiên (Priority):** P3
- **Vị trí code:** `app/lib/features/me/presentation/me_screen.dart` (dòng 44–84, 107–133, 255–292)
- **Các điểm lệch quan sát được:**
  1. **Nhóm "Đội của tôi":**
     - **Mong đợi (Bản vẽ Màn 23):** Cuối danh sách đội có dòng hành động màu xanh `#0066CC`: `"Tạo hoặc tham gia đội khác"`.
     - **Thực tế (`me_screen.dart`):** Chỉ liệt kê các đội hiện có, thiếu dòng `"Tạo hoặc tham gia đội khác"`.
  2. **Nhóm "Hoạt động":**
     - **Mong đợi (Bản vẽ Màn 23):** Mỗi dòng trong nhóm **Hoạt động** có biểu tượng nền màu bo góc `8px` (`30×30px`: xanh dương `#0066CC` cho *Kèo của tôi*, xanh lá `#248A3D` cho *Lịch sử đặt sân*, cam `#B25000` cho *Quỹ của tôi*, vàng `#C69200` cho *Danh hiệu*).
     - **Thực tế (`me_screen.dart`):** Chỉ có 2 dòng chữ thuần (`Kèo của tôi`, `Danh hiệu`) không có biểu tượng màu `leading`, và chưa có 2 mục lối tắt `Lịch sử đặt sân`, `Quỹ của tôi`.
  3. **Thẻ Hồ sơ cầu thủ (`_Profile`):**
     - **Mong đợi (Bản vẽ Màn 23):** Hiển thị trực tiếp trên nền `#F5F5F7` (không bọc trong thẻ trắng), Avatar kích thước `76×76px` (`font-size: 26px`), tên cầu thủ `26px bold`.
     - **Thực tế (`_Profile`):** Bọc trong `AppCard` nền trắng, Avatar kích thước `64×64px`.