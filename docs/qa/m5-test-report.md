# Báo Cáo Kết Quả Kiểm Thử Tổng Hợp Chặng M5: Cộng Đồng (Sân 7)

- **Ngày thực hiện:** 17/11/2026
- **Người thực hiện:** QA
- **Nhánh kiểm thử:** `m5-cong-dong` (`C:\source_code\sân7\san7-be`, commit `HEAD 535ef99`)
- **Môi trường kiểm thử:**
  - **Backend & Hạ tầng Docker:** `san7-api-1` (`http://localhost:3001`), `san7-worker-1`, `san7-postgres-1` (PostgreSQL 16 cổng `5432`), `san7-redis-1` (Redis 7 cổng `6379`), `san7-storage-1` (SeaweedFS S3 cổng `8333`).
  - **Frontend Flutter:** `C:\source_code\sân7\san7-be\app` (`flutter analyze`, `flutter test`).
  - **Thiết bị vật lý & Ảnh chụp màn hình thực tế:** Điện thoại Android `PLG110` (`3B161L00EW800000`) — 6 ảnh chụp thực tế tại `docs/design/screens/` (`01-bang-tin.png`, `10-keo-cua-toi.png`, `14-binh-luan.png`, `21-nhan-tin.png`, `23-ca-nhan.png`, `24-cam-xuc.png`). *(Lưu ý trung thực: Trong lượt chạy xác minh lại sau 09:37, cáp USB của máy `PLG110` bị ngắt kết nối vật lý nên `adb devices -l` trống; các bản vá UI sau 09:08 được kiểm chứng qua `flutter test` 46/46 PASS + `flutter analyze` 0 lỗi + rà soát code trực tiếp).*
- **Tài liệu tham chiếu:**
  - Bộ Test Case M5: `docs/qa/m5-test-cases.md`
  - Báo cáo lỗi chi tiết: `docs/qa/m5-bugs.md`
  - Báo cáo Review & Bảo mật: `docs/reviews/m5-review.md`, `docs/reviews/m5-security-review.md`
  - Tiêu chí nghiệm thu BA: `docs/stories/m5-acceptance.md`

---

## 1. Tổng Quan Kết Quả & Đánh Giá Sẵn Sàng Phát Hành (Executive Summary)

### 1.1. Thống kê các bộ kiểm thử đã chạy thực tế

| Hạng mục kiểm thử | Tổng số | Đạt (PASS) | Chưa đạt / Cảnh báo | Tỷ lệ PASS | Ghi chú thực tế |
|---|---:|---:|---:|---:|---|
| **Test Case Nghiệp vụ, Giao diện & Bảo mật (`m5-test-cases.md`)** | **30 TC** | **28 TC** | **2 TC** *(PASS có điều kiện / lỗi nhẹ S4)* | **93.3%** | `TC-IMG-01` chờ rebuild container `san7-api-1` (`BUG-M5-10`); `TC-CMT-06` phát hiện lỗi biên nhỏ `BUG-M5-11` (`body: "   "`). |
| **Kịch bản API & Bảo mật trực tiếp (`http://localhost:3001` + DB/S3)** | **42 kịch bản** | **40 kịch bản** | **2 kịch bản** | **95.2%** | Kịch bản #10 (`GET publicUrl` trên container cũ chưa rebuild `ad3a15d`) và kịch bản #38 (`POST /comments` chỉ chứa khoảng trắng). |
| **4 Chốt chặn Bảo mật bắt buộc (Security Blockers)** | **4 Blocker** | **4 Blocker** | **0** *(Lưu ý CVE `sharp`)* | **100%** | Cả 4 cơ chế bảo vệ (`TC-SEC-01` → `TC-SEC-04`) đều hoạt động đúng trên DB + SeaweedFS + Socket.IO + Redis/BullMQ. |
| **Backend Unit Tests (`npm test -- --run`)** | **214 tests** (26 files) | **214 PASS** | **0 FAIL** | **100%** | Bao phủ `community`, `media`, `schedules`, `chat`, `realtime`, `me`, `posts`... |
| **Backend Integration Tests (`npm run test:int` trên Postgres + Redis thật)** | **3 tests** (1 file) | **3 PASS** | **0 FAIL** | **100%** | `test/int/schedules.int-spec.ts` kiểm chứng BullMQ v5 + huỷ lịch khi tác giả bị hạ quyền (`C6`). |
| **Backend E2E Tests (`npm run test:e2e`)** | **15 tests** (4 files) | **15 PASS** | **0 FAIL** | **100%** | Tất cả luồng E2E đạt 100%. |
| **Flutter Static Analysis (`flutter analyze`)** | Toàn bộ `app/` | **0 lỗi, 0 cảnh báo** | **0** | **100%** | `No issues found!` |
| **Flutter Widget & Unit Tests (`flutter test`)** | **46 tests** | **46 PASS** | **0 FAIL** | **100%** | Bao gồm test Màn 1, 2, 10, 14, 21, 23, 24. |

### 1.2. Kết luận nghiệm thu (QA Verdict)
- **Trạng thái chức năng & nghiệp vụ M5:** **ĐẠT (PASS)** — Toàn bộ 6 lỗi chức năng từ vòng trước (`BUG-M5-01` đến `BUG-M5-06`) và cả **4 Security Blockers** trong `docs/reviews/m5-review.md` đã được sửa và kiểm chứng.
- **Điều kiện cần hoàn tất trước khi gộp nhánh (Merge Gate):**
  1. **Cập nhật gói `sharp` & Rebuild container `san7-api-1` / `san7-worker-1` (Mức Cao / P1):** Commit `ad3a15d` đã sửa xong luồng quarantine + re-encode WebP + `/v1/media/public/:id` trong mã nguồn, nhưng container `san7-api-1` đang chạy bản build cũ trước `09:19` nên gọi `GET` ảnh công khai trên container hiện tại bị `403` (`BUG-M5-10`), đồng thời `npm audit --omit=dev --audit-level=high` báo 1 CVE mức High ở `sharp ^0.34.5` (cần nâng lên `>= 0.35.5`).
  2. *(Tuỳ chọn / S4)* Bổ sung `@MinLength(1)` cho `CreateCommentDto.body` trong `backend/src/community/community.dto.ts` để chặn bình luận chỉ toàn khoảng trắng (`BUG-M5-11`).

---

## 2. Kết Quả Chi Tiết Từng Test Case (`docs/qa/m5-test-cases.md`)

### 2.1. Màn 10 — Kèo của tôi & lịch đăng (`TC-M10-01` → `TC-M10-07`)

| Mã TC | Kịch bản kiểm thử | Phương thức xác minh | Kết quả | Chi tiết quan sát thực tế |
|---|---|---|---|---|
| **TC-M10-01** | Xem danh sách kèo ở tab **Đang mở** và điều hướng So sánh / Chi tiết kèo | API `GET /v1/me/posts?status=open` + Ảnh chụp máy thật `10-keo-cua-toi.png` + Widget test | **PASS** | Hiển thị đúng tiêu đề `Kèo của tôi`, thanh phân đoạn 3 tab (`Đang mở · 1`, `Lịch đăng`, `Đã chốt`), thẻ kèo hiện loại kèo, giờ đá, sân và nút điều hướng sang Màn 11 / Màn 14. |
| **TC-M10-02** | Xem danh sách kèo ở tab **Đã chốt** | API `GET /v1/me/posts?status=matched` + Code / Widget test | **PASS** | API trả `200 OK` đúng danh sách kèo `matched` của user kèm mảng `media`; hỗ trợ kéo làm mới (`RefreshIndicator`). |
| **TC-M10-03** | Tạo lịch hẹn đăng kèo một lần và lặp hàng tuần (`POST / GET /v1/teams/:teamId/post-schedules`) | API trực tiếp + Integration test `schedules.int-spec.ts` + Code Màn 2 & Màn 10 | **PASS** *(Đã sửa `BUG-M5-01`, `BUG-M5-02`, `BUG-M5-03`)* | `POST` trả `201 Created` (đã bỏ dấu `:` trong `jobId` BullMQ v5); `GET` trả `200 OK` danh sách lịch đăng; Màn 2 đã có mục `"Thời điểm đăng"` (`Đăng ngay` / `Hẹn lịch` + `Lặp lại hàng tuần`); Màn 10 đã có `PostSchedulesTab`. |
| **TC-M10-04** | Sửa và Huỷ lịch hẹn đăng kèo (`PATCH / DELETE`) | API trực tiếp + UI `PostSchedulesTab` | **PASS** *(Đã sửa `BUG-M5-01`)* | `PATCH` trả `200 OK` cập nhật lịch hẹn và xếp lại job; `DELETE` trả `204 No Content` (gọi lần 2 trả `404 post_schedule_not_found`); trên UI có hộp thoại xác nhận `"Huỷ lịch đăng?"`. |
| **TC-M10-05** | Trạng thái Loading, Empty State và Error / Offline | Widget test + Rà soát `my_posts_screen.dart`, `post_schedules_tab.dart` | **PASS** | Đủ 3 trạng thái: `CircularProgressIndicator`, màn trống tiếng Việt rõ ràng (không có dữ liệu giả), và màn lỗi có nút `"Thử lại"`. |
| **TC-M10-06** | Quyền tạo/sửa/huỷ/xem lịch đăng và ràng buộc thời gian | API trực tiếp (`#22`, `#23`) | **PASS** | Thành viên thường (`member`) bị chặn với `403 team_role_required`; giờ hẹn ở quá khứ bị chặn với `400 schedule_in_past`. |
| **TC-M10-07** | Visual QA Màn 10 so với `san7-ui.html` | Ảnh chụp `10-keo-cua-toi.png` + Commit `2f91e96` | **PASS** *(Còn lệch nhẹ S4 — `BUG-M5-07`)* | Commit `2f91e96` đã sửa nút `< Bảng tin` và nút `+` tròn `44×44px` góc phải. Thẻ `_MyPostCard` vẫn dùng `SoftButton` trải rộng thay vì pill xanh góc phải trên (mức S4, không chặn luồng). |

---

### 2.2. Màn 21 — Nhắn tin giữa 2 đội, Realtime (`TC-M21-01` → `TC-M21-08`)

| Mã TC | Kịch bản kiểm thử | Phương thức xác minh | Kết quả | Chi tiết quan sát thực tế |
|---|---|---|---|---|
| **TC-M21-01** | Mở màn Chat, hiển thị thẻ kèo ghim đầu màn và lịch sử tin nhắn | Ảnh chụp máy thật `21-nhan-tin.png` + API `GET /v1/matches/:id/messages` | **PASS** | Hiển thị đúng tên đội đối thủ trên header, thẻ kèo ghim đầu màn (`Th 5, 19/11 · 19:00 · Sân Thành Phát · Cầu Giấy`), danh sách tin nhắn và 3 chip gợi ý nhanh. |
| **TC-M21-02** | Gửi tin nhắn văn bản, bấm chip gợi ý nhanh và nhận tin nhắn Realtime qua Socket.IO | API `POST /v1/matches/:id/messages` + 2 client `socket.io-client` thật + Ảnh chụp `21-nhan-tin.png` | **PASS** | Tin nhắn tự động `trim()`, lưu DB (`201 Created`) và phát sự kiện `chat.message` tức thời sang socket của đội đối phương; chống nhân đôi theo `id`. |
| **TC-M21-03** | Phân trang tải thêm tin nhắn cũ khi cuộn ngược lên | API `GET /v1/matches/:id/messages?limit=5&cursor=...` + Code `chat_screen.dart` | **PASS** | Phân trang cursor hoạt động chính xác, nối tiếp tin nhắn cũ khi `extentAfter < 160`. |
| **TC-M21-04** | Trạng thái Loading, Empty, mất mạng & đang gửi (Sending) | Widget test + Code `chat_screen.dart` | **PASS** | Khoá gửi trùng khi `_sending = true`; khi gửi lỗi hiện toast tiếng Việt và giữ nguyên nội dung trong ô nhập để gửi lại. |
| **TC-M21-05** | Phân quyền: Người ngoài hai đội không xem/gửi được chat (REST & Socket.IO) | API trực tiếp (`#28`) + Socket.IO `match:join` | **PASS** | REST trả `403 chat_forbidden`; Socket.IO `match:join` trả ack `{ ok: false }`. |
| **TC-M21-06** | Trận đã huỷ (`status = cancelled`) chỉ cho phép đọc, chặn gửi tin nhắn mới | API trực tiếp (`#29`) + Commit `3eb848b` (`chat_screen.dart`) | **PASS** *(Đã sửa `BUG-M5-05`)* | `GET` trả `200 OK`; `POST` trả `409 match_cancelled`; UI `ChatScreen` ẩn ô nhập/chip gợi ý và hiện thanh `_CancelledBar` (`"Trận đã huỷ, chỉ đọc được tin nhắn cũ"`). |
| **TC-M21-07** | Giá trị biên nội dung tin nhắn (`body`) và `matchId` | API trực tiếp (`#27`, `#30`) | **PASS** | `body: "   "` hoặc `> 1000` ký tự trả `400 validation_failed`; sai UUID trả `400`, UUID không tồn tại trả `404 match_not_found`. |
| **TC-M21-08** | Visual QA Màn 21 so với `san7-ui.html` | Ảnh chụp `21-nhan-tin.png` + Commit `3eb848b` | **PASS** *(Còn lệch nhẹ S4 — `BUG-M5-08`)* | Commit `3eb848b` đã sửa góc nhọn `6px` của bong bóng chat. Header vẫn dùng chữ đơn giản chưa có avatar/phụ đề đội trưởng (mức S4). |

---

### 2.3. Màn 23 — Cá nhân & cài đặt (`TC-M23-01` → `TC-M23-06`)

| Mã TC | Kịch bản kiểm thử | Phương thức xác minh | Kết quả | Chi tiết quan sát thực tế |
|---|---|---|---|---|
| **TC-M23-01** | Hiển thị Hồ sơ cầu thủ, Thống kê 4 chỉ số, Đội của tôi và Hoạt động | Ảnh chụp máy thật `23-ca-nhan.png` + API `GET /v1/me` | **PASS** | Hiển thị đúng Avatar, Tên (`Phạm Ngọc Duy`), Vị trí · Số áo (`Tiền đạo · Số 9`), 4 ô thống kê (`Trận`, `Bàn`, `Kiến tạo`, `MVP`), Đội của tôi và Hoạt động. |
| **TC-M23-02** | Chỉnh sửa hồ sơ cầu thủ (`PATCH /v1/me` & `EditProfileScreen`) | API trực tiếp (`#4`, `#5`) + Commit `2f91e96` (`me_screen.dart`, `edit_profile_screen.dart`) | **PASS** *(Đã sửa `BUG-M5-04`)* | Header Màn 23 đã có nút `"Sửa"` và dòng `"Khu vực"` mở `EditProfileScreen`; `PATCH /v1/me` cập nhật thành công và chặn đúng các giá trị vượt biên (`shirtNumber > 99`, tên rỗng). |
| **TC-M23-03** | Bật / Tắt cài đặt thông báo (`GET / PATCH /v1/me/notification-settings`) | API trực tiếp (`#6`, `#7`, `#8`) + Ảnh chụp `23-ca-nhan.png` | **PASS** | 3 công tắc (`Kèo & trận đấu`, `Hoạt động đội`, `Cộng đồng`) đồng bộ chính xác với server. |
| **TC-M23-04** | Xử lý lỗi mạng khi tải hoặc đổi cài đặt thông báo | Code `me_screen.dart` + Widget test | **PASS** | Khối thông báo dùng `AsyncView` có nút `"Thử lại"`, báo lỗi toast tiếng Việt khi mất mạng. |
| **TC-M23-05** | Đăng xuất có hộp thoại xác nhận | Ảnh chụp `23-ca-nhan.png` + Code `me_screen.dart` | **PASS** | Bấm `"Đăng xuất"` mở hộp thoại xác nhận `"Đăng xuất?"` với 2 nút `"Huỷ"` / `"Đăng xuất"`. |
| **TC-M23-06** | Visual QA Màn 23 so với `san7-ui.html` | Ảnh chụp `23-ca-nhan.png` + Commit `2f91e96` | **PASS** *(Còn lệch nhẹ S4 — `BUG-M5-09`)* | Bố cục rõ ràng, các dòng đạt `>= 48px`. Còn thiếu dòng `"Tạo hoặc tham gia đội khác"` và icon màu ở nhóm Hoạt động (mức S4). |

---

### 2.4. Luồng Đăng kèo kèm ảnh (`TC-IMG-01` → `TC-IMG-04`)

| Mã TC | Kịch bản kiểm thử | Phương thức xác minh | Kết quả | Chi tiết quan sát thực tế |
|---|---|---|---|---|
| **TC-IMG-01** | Xin Presigned URL, tải ảnh lên SeaweedFS S3, xử lý lại WebP và đăng kèo kèm ảnh | API trực tiếp (`#9`, `#10`, `#14`) + Kiểm thử trực tiếp `MediaService` (`ad3a15d`) + UI `PostCreateScreen` | **PASS có điều kiện** *(Chờ rebuild container — `BUG-M5-10`)* | Khi chạy `MediaService` bản `ad3a15d` với Postgres + SeaweedFS thật: ảnh PNG tải lên `quarantine/` được chuyển sang `image/webp` (`64 bytes`) và đọc qua `readPublicImage` thành công. Tuy nhiên container `san7-api-1` đang chạy bản cũ chưa rebuild nên `GET` ảnh trên container hiện tại trả `403`. |
| **TC-IMG-02** | Chặn định dạng file không được phép (`415`) và dung lượng vượt quá 10MB (`413`) | API trực tiếp (`#11`, `#12`, `#13`, `#17`) | **PASS** *(Đã sửa `BUG-M5-06`)* | Sai MIME trả `415 media_type_not_allowed`; `size > 10MB` trả `413 media_too_large`; `purpose: "receipt"` trả `201 Created`; quá 4 ảnh trả `400 validation_failed`. |
| **TC-IMG-03** | Bảo mật kho ảnh: Chặn gắn `key` của user khác, sai `purpose` hoặc `key` chưa upload thật | API trực tiếp (`#15`, `#16`) + Unit test `media.service.spec.ts` | **PASS** | Gắn `key` của người khác hoặc `purpose = avatar` trả `403 media_forbidden`; gắn `key` chưa PUT lên S3 trả `400 media_not_uploaded`. |
| **TC-IMG-04** | Trạng thái hiển thị ảnh trên UI (Màn 1, 2, 14) | Ảnh chụp `01-bang-tin.png`, `14-binh-luan.png` + Code `post_image_picker.dart`, `post_media_gallery.dart` | **PASS** | Màn 2 có `PostImagePicker` (chọn tối đa 4 ảnh, xoá ảnh bằng nút `×`); Màn 1 & 14 có `PostMediaGallery` kèm placeholder và icon báo lỗi khi ảnh hỏng. |

---

### 2.5. Màn 1, 14, 24 — Bình luận & Cảm xúc bài kèo (`TC-CMT-01` → `TC-CMT-07`)

| Mã TC | Kịch bản kiểm thử | Phương thức xác minh | Kết quả | Chi tiết quan sát thực tế |
|---|---|---|---|---|
| **TC-CMT-01** | Thả cảm xúc (`like`, `love`, `fire`, `laugh`, `sad`), đổi loại cảm xúc và gỡ cảm xúc | API trực tiếp (`#31`, `#34`) + Ảnh chụp `01-bang-tin.png`, `14-binh-luan.png` | **PASS** | `PUT /v1/posts/:id/reaction` cập nhật idempotent (`total: 1`, `myReaction: "love"`); `DELETE` gỡ cảm xúc (`myReaction: null`). |
| **TC-CMT-02** | Xem danh sách người thả cảm xúc và lọc theo từng tab cảm xúc trên Màn 24 (`ReactionsScreen`) | API trực tiếp (`#33`) + Ảnh chụp máy thật `24-cam-xuc.png` + Widget test | **PASS** | Màn 24 hiển thị đúng các chip lọc (`Tất cả 3`, `🔥 1`, `❤️ 1`, `👍 1`), danh sách người thả cảm xúc có huy hiệu emoji góc avatar, tên, đội · vị trí và thời gian. |
| **TC-CMT-03** | Viết bình luận và trả lời bình luận 1 cấp (`parentId`) trên Màn 14 | API trực tiếp (`#35`) + Ảnh chụp máy thật `14-binh-luan.png` | **PASS** | Tạo bình luận gốc và bình luận trả lời (`parentId`) trả `201 Created`; trên Màn 14 hiển thị đúng cấu trúc bình luận cha và phản hồi thụt lề bên dưới. |
| **TC-CMT-04** | Chặn trả lời lồng quá 1 cấp (`400 comment_nested_reply`) hoặc `parentId` không tồn tại (`404`) | API trực tiếp (`#36`) + Unit test `community.service.spec.ts` | **PASS** | Trả lời vào một reply bị chặn với HTTP `400 Bad Request` (`code: "comment_nested_reply"`). |
| **TC-CMT-05** | Quyền xoá bình luận: Tác giả hoặc Đội trưởng/Phó đội chủ bài kèo xoá được (`204`); người ngoài bị chặn (`403`) | API trực tiếp (`#37`) | **PASS** | Người thứ 3 gọi `DELETE` bị chặn `403 comment_delete_forbidden`; tác giả hoặc `captain` đội chủ bài kèo xoá thành công (`204 No Content`). |
| **TC-CMT-06** | Giá trị biên nội dung bình luận (`body`) và loại cảm xúc (`type`) | API trực tiếp (`#32`, `#38`) | **FAIL nhẹ (S4 / P3)** *(Xem `BUG-M5-11`)* | Sai enum reaction trả `400`; `body: ""` hoặc `> 1000` ký tự trả `400`. Tuy nhiên `body: "   "` (chỉ có khoảng trắng) hiện trả `201 Created` với `body: ""` vì `CreateCommentDto` thiếu `@MinLength(1)` sau `@Trim()`. |
| **TC-CMT-07** | Trạng thái Loading / Empty / Error & Visual QA Bình luận (Màn 14) và Cảm xúc (Màn 24) | Ảnh chụp `01-bang-tin.png`, `14-binh-luan.png`, `24-cam-xuc.png` + Widget test | **PASS** | Giao diện Màn 14 và Màn 24 trên thiết bị thật `PLG110` sắc nét, đúng bố cục thiết kế, không lỗi tràn chữ. |

---

### 2.6. Kiểm Thử 4 Chốt Chặn Bảo Mật Bắt Buộc (`TC-SEC-01` → `TC-SEC-04`)

| Mã TC | Chốt chặn bảo mật (`docs/reviews/m5-review.md`) | Phương thức xác minh thực tế | Kết quả | Bằng chứng kiểm thử |
|---|---|---|---|---|
| **TC-SEC-01** | **Blocker #1 (C7):** Chặn upload file giả mạo MIME (`<html><script>...` đội lốt `image/jpeg`), kiểm tra kích thước thực, giải mã & mã hoá lại sang WebP bằng `sharp` | Chạy `MediaService` (`ad3a15d`) trực tiếp với Postgres + SeaweedFS S3 thật + `media.service.spec.ts` | **PASS** *(Trên code `ad3a15d`)* | Khi đẩy `<html><script>alert(1)</script></html>12345` (43 bytes) lên `quarantine/` với `Content-Type: image/jpeg` rồi gọi `assertUsablePostMedia`: `sharp` bác bỏ ngay với HTTP **`415 Unsupported Media Type`** (`{"code":"invalid_image_content","message":"File tải lên không phải ảnh hợp lệ"}`) và xoá file khỏi `quarantine/`. Ảnh PNG hợp lệ được chuyển sang `image/webp` và phục vụ kèm `X-Content-Type-Options: nosniff`. |
| **TC-SEC-02** | **Blocker #2 (C7):** Giới hạn quota tải ảnh `50MB/ngày/user` (`Serializable` transaction) và job `media-cleanup` xoá ảnh mồ côi quá hạn | Chạy `MediaService` (`ad3a15d`) trực tiếp với Postgres + SeaweedFS S3 thật + `media.service.spec.ts` | **PASS** *(Trên code `ad3a15d`)* | Khi user đã có `48MB` trong ngày và xin upload thêm `3MB`: trả về HTTP **`429 Too Many Requests`** (`{"code":"media_daily_quota_exceeded","message":"Đã dùng hết quota tải ảnh hôm nay"}`). Khi chạy `cleanupExpired(new Date())`: xoá bản ghi `pending` quá hạn (`cleaned = 1`). |
| **TC-SEC-03** | **Blocker #3 (C1 & C2):** Thu hồi kết nối Socket.IO (`evictFromTeam`) ngay khi thành viên bị loại hoặc tự rời đội; ngắt socket khi JWT hết hạn | Kiểm thử live trên Docker (`http://localhost:3001/v1/socket`) với 2 client `socket.io-client` + `realtime.gateway.spec.ts` | **PASS** | Khi `captain` gọi `DELETE /v1/teams/:teamId/members/:userC` hoặc `userC` gọi `DELETE .../members/me` (`204 No Content`), socket của `userC` bị ngắt tức thì (`disconnected = true`), không nhận được tin nhắn mới (`received = 0`), và thử `match:join` lại bằng JWT cũ bị từ chối `{ ok: false }`. Khi JWT hết hạn, server bắn `auth:error { code: "token_expired" }` và ngắt kết nối. |
| **TC-SEC-04** | **Blocker #4 (C6):** Lịch đăng kèo tự động (`post_schedules`) không được đăng bài nếu tác giả đã bị hạ quyền xuống `member` hoặc rời đội | Chạy integration test `npm run test:int` (`test/int/schedules.int-spec.ts`) trên Postgres + Redis thật | **PASS** | Test `"tác giả mất quyền đội phó sau khi hẹn lịch -> tới giờ không đăng bài và huỷ lịch"` chạy **PASS**: lịch chuyển sang `status = "cancelled"`, `publishedPostId = null` và `posts.count = 0`. |

---

## 3. Danh Sách Các Vấn Đề Còn Tồn Đọng Phân Loại Theo Mức Độ Nghiêm Trọng (Remaining Issues by Severity)

### 3.1. Mức Cao (High / S2 — P1: Cần xử lý trước khi gộp nhánh / deploy)

1. **`BUG-M5-10` — Container `san7-api-1` đang chạy chưa được rebuild với commit `ad3a15d` nên `GET` ảnh công khai trả về `403 Forbidden`**
   - **Thành phần:** Hạ tầng Docker / Backend (`media`)
   - **Hiện trạng:** Trong mã nguồn (`HEAD 535ef99`, commit `ad3a15d`), `MediaService` đã chuyển `publicUrl` sang `GET /v1/media/public/:id` (đã xác minh chạy PASS khi gọi trực tiếp `MediaService` với Postgres + SeaweedFS). Tuy nhiên container `san7-api-1` đang chạy được build từ `01:58 UTC` (trước commit `ad3a15d`), nên API trên container vẫn trả `publicUrl` trỏ thẳng vào `http://localhost:8333/media/...` (bị SeaweedFS chặn `403 AccessDenied`) và chưa có route `GET /v1/media/public/:id`.
   - **Hành động cần làm:** Rebuild image `san7-backend:local` và khởi động lại `san7-api-1`, `san7-worker-1` (`docker compose up -d --build api worker`).

2. **`SEC-M5-C7` — Cảnh báo lỗ hổng mức High trong gói `sharp` (`npm audit`) & kiểm tra chủ sở hữu trong `assertOwnedKey`**
   - **Thành phần:** `backend/package.json`, `backend/src/media/media.service.ts:130`
   - **Hiện trạng:**
     - Chạy `npm audit --omit=dev --audit-level=high` trong `backend/` báo 1 lỗ hổng mức **High** ở `sharp <= 0.35.5-rc.1` (hiện `package.json` đang khai báo `"sharp": "^0.34.5"`).
     - Hàm `assertOwnedKey(_userId: string, key: string)` (`backend/src/media/media.service.ts:130`) hiện chỉ kiểm tra định dạng regex `^public/[0-9a-f-]{36}\.webp$` mà bỏ qua tham số `_userId` (quyền sở hữu thực tế được kiểm tra ở bước `finalizeUpload(userId, key)`).
   - **Hành động cần làm:** Nâng cấp `sharp` lên bản vá mới nhất (`>= 0.35.5` hoặc cập nhật gói phụ thuộc theo advisory) trước khi đóng gói image sản phẩm.

---

### 3.2. Mức Thấp (Low / S4 — P3: Không chặn phát hành, có thể đưa vào backlog M6)

3. **`BUG-M5-11` *(Mới)* — `POST /v1/posts/:postId/comments` chấp nhận bình luận chỉ gồm khoảng trắng (`"   "`) tạo ra bản ghi `body: ""`**
   - **Thành phần:** `backend/src/community/community.dto.ts:24-27`
   - **Hiện trạng:** `CreateCommentDto.body` có `@Trim()`, `@IsString()`, `@MaxLength(1000)` nhưng thiếu `@MinLength(1)` (khác với `SendMessageDto.body` của Chat có `@MinLength(1)`). Khi gửi `{"body": "   "}`, `@Trim()` biến chuỗi thành `""` và vẫn vượt qua `@IsString()`, trả về HTTP `201 Created` với `body: ""`.
   - **Cách sửa:** Thêm `@MinLength(1)` vào `CreateCommentDto.body`.

4. **`BUG-M5-07` — Lệch nhỏ giao diện thẻ kèo trên Màn 10 (`MyPostsScreen`) so với `san7-ui.html`**
   - **Thành phần:** `app/lib/features/me/presentation/my_posts_screen.dart:118-175`
   - **Hiện trạng:** Header `< Bảng tin` và nút `+` tròn góc phải đã được sửa ở commit `2f91e96`. Thẻ `_MyPostCard` vẫn dùng nút `SoftButton` trải rộng `"N đội muốn nhận · So sánh"` thay vì pill xanh `#0066CC` ở góc phải trên + link `"So sánh & chọn đội"`.

5. **`BUG-M5-08` — Lệch nhỏ header và thẻ kèo ghim trên Màn 21 (`ChatScreen`) so với `san7-ui.html`**
   - **Thành phần:** `app/lib/features/chat/presentation/chat_screen.dart:96-103, 189-215`
   - **Hiện trạng:** Bong bóng chat góc nhọn `6px` và thanh khoá chat khi trận `cancelled` đã được sửa ở commit `3eb848b`. Header vẫn dùng `DetailHeader` chữ đơn giản (chưa có avatar đội đối thủ, dòng phụ đề tên đội trưởng và nút gọi điện).

6. **`BUG-M5-09` — Lệch nhỏ giao diện Màn 23 (`MeScreen`) so với `san7-ui.html`**
   - **Thành phần:** `app/lib/features/me/presentation/me_screen.dart:50-100`
   - **Hiện trạng:** Nút `"Sửa"` và dòng `"Khu vực"` đã được bổ sung ở commit `2f91e96`. Nhóm `"Đội của tôi"` chưa có dòng `"Tạo hoặc tham gia đội khác"`, nhóm `"Hoạt động"` chưa có icon nền màu `30×30px` ở đầu dòng.

---

## 4. Ghi Chú Trung Thực Về Phạm Vi Đã Xác Minh vs Chưa Xác Minh Trực Tiếp

- **Đã xác minh trực tiếp bằng lệnh & công cụ thật:**
  - Toàn bộ 42 kịch bản API & Bảo mật trên Postgres, Redis, SeaweedFS S3 và Socket.IO.
  - Toàn bộ bộ test tự động Backend (`214` unit tests + `3` integration tests + `15` E2E tests) và Frontend (`flutter analyze` 0 lỗi + `46` widget tests).
  - 6 ảnh chụp màn hình thực tế trên điện thoại `PLG110` tại `docs/design/screens/` (`01`, `10`, `14`, `21`, `23`, `24`).
- **Chưa thể bấm lại trực tiếp trên màn hình vật lý sau 09:37:**
  - Do điện thoại `PLG110` (`3B161L00EW800000`) bị rút/lỏng cáp USB khỏi máy host sau `09:37` (`adb devices -l` trống), các bản vá giao diện mới nhất sau `09:08` (`PostCreateScreen` chọn lịch đăng, `MeScreen` nút Sửa, `ChatScreen` thanh chỉ đọc khi trận huỷ, `MyPostsScreen` nút `< Bảng tin` & `+`) đã được xác minh qua `flutter test` (`46/46 PASS`) và đọc mã nguồn, chờ cắm lại cáp USB để chụp lại ảnh màn hình mới nhất nếu cần.
  - Route `GET /v1/media/public/:id` đã được xác minh ở tầng `MediaService` với Postgres + SeaweedFS thật, chờ lệnh rebuild container `san7-api-1` để gọi qua cổng HTTP `:3001`.
