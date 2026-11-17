# Tiêu chí nghiệm thu Chặng M5: Cộng đồng (Sân 7)

- **Phiên bản:** 1.1 | **Ngày cập nhật:** 17/11/2026
- **Người viết:** BA (kiêm PO)
- **Đối tượng sử dụng:** PM Sân 7, QA, Frontend Dev, Backend Dev, Teamlead
- **Phạm vi:** Các tính năng thuộc chặng M5 (Kèo của tôi & hẹn lịch đăng, Bình luận & Cảm xúc + Danh sách cảm xúc, Chat realtime giữa hai đội, Cá nhân & Cài đặt thông báo, Tải ảnh lên kho lưu trữ kèm quarantine/re-encode & hiển thị ảnh trong kèo).
- **Tham chiếu thiết kế & bảo mật:** `docs/design/san7-ui.html` (Màn 1, 2, 10, 14, 21, 23, 24), `docs/PLAN.md` (mục 6, 7, 8, 11), `docs/HANDOVER.md`, và `docs/reviews/m5-review.md`.

---

## Mục lục

1. [Quyết định PO: Phân quyền Phó đội (`vice`) & Chính sách thu hồi quyền M5](#0-quyết-định-po-phân-quyền-phó-đội-vice--chính-sách-thu-hồi-quyền-m5)
2. [US-M5-01: Kèo của tôi & Hẹn lịch đăng kèo (Màn 2, 10)](#us-m5-01-kèo-của-tôi--hẹn-lịch-đăng-kèo-màn-2-10)
3. [US-M5-02: Bình luận & Cảm xúc trên kèo + Danh sách cảm xúc (Màn 1, 14, 24)](#us-m5-02-bình-luận--cảm-xúc-trên-kèo--danh-sách-cảm-xúc-màn-1-14-24)
4. [US-M5-03: Nhắn tin (Chat) realtime giữa hai đội trong trận (Màn 9, 13, 17, 18, 21, 22)](#us-m5-03-nhắn-tin-chat-realtime-giữa-hai-đội-trong-trận-màn-9-13-17-18-21-22)
5. [US-M5-04: Hồ sơ cá nhân, Thống kê cầu thủ & Cài đặt thông báo (Màn 23)](#us-m5-04-hồ-sơ-cá-nhân-thống-kê-cầu-thủ--cài-đặt-thông-báo-màn-23)
6. [US-M5-05: Tải ảnh lên kho S3 (Quarantine & Re-encode) + Ảnh trong kèo (Màn 1, 2, 14)](#us-m5-05-tải-ảnh-lên-kho-s3-quarantine--re-encode--ảnh-trong-kèo-màn-1-2-14)
7. [Ma trận kiểm thử trạng thái giao diện & mạng xuyên suốt M5](#7-ma-trận-kiểm-thử-trạng-thái-giao-diện--mạng-xuyên-suốt-m5)

---

## 0. Quyết định PO: Phân quyền Phó đội (`vice`) & Chính sách thu hồi quyền M5

Để thống nhất giữa bản vẽ `docs/design/san7-ui.html`, mã nguồn Backend và yêu cầu bảo mật tại `docs/reviews/m5-review.md`, BA/PO chốt chính thức các quy tắc phân quyền sau cho M5:

### 0.1. Ma trận quyền của Phó đội (`vice`) so với các vai trò khác trong M5

| Nghiệp vụ / Hành động | Đội trưởng (`captain`) | Phó đội (`vice`) | Thủ quỹ (`treasurer`) | Thành viên (`member`) | Ghi chú thực thi |
|---|:---:|:---:|:---:|:---:|---|
| **Đăng kèo ngay (`POST /v1/teams/:teamId/posts`)** | Có | **Có** | Không | Không | Guard `@TeamRoles('captain', 'vice')` |
| **Xem danh sách lịch đăng của đội (`GET /v1/teams/:teamId/post-schedules`)** | Có | **Có** | Có | Có | Mọi thành viên `active` trong đội xem được lịch chung |
| **Tạo / Sửa / Huỷ lịch hẹn đăng kèo (`POST/PATCH/DELETE .../post-schedules`)** | Có | **Có** | Không | Không | Guard `@TeamRoles('captain', 'vice')` |
| **Đặt sân giữ chỗ & quản lý lịch/điểm danh đội** | Có | **Có** | Không | Không | Thống nhất mô tả quyền Phó đội ở Màn 19 |
| **Tham gia phòng Chat & gửi tin nhắn trận đấu (`match:{matchId}`)** | Có | **Có** | Có | Có | Mọi thành viên `active` thuộc `homeTeam` hoặc `awayTeam` |
| **Viết bình luận & thả cảm xúc trên kèo** | Có | **Có** | Có | Có | Mọi người dùng đã đăng nhập |
| **Xoá bình luận trên kèo (`DELETE /v1/posts/:postId/comments/:commentId`)** | Tác giả bình luận hoặc Tác giả bài kèo | **Tác giả bình luận hoặc Tác giả bài kèo** | Chỉ bình luận của chính mình | Chỉ bình luận của chính mình | **Quyết định M5:** Quyền quản trị xoá bình luận trên kèo gắn theo `post.authorId` (nếu `vice` là người đăng kèo thì xoá được mọi bình luận trên kèo đó; mở rộng cho mọi `captain`/`vice` cùng đội vào M6 nếu cần) |

### 0.2. Chính sách xử lý Lịch hẹn đăng kèo khi tác giả mất quyền (Author Demotion / Removal Policy)
- **Quyết định chốt:** **Huỷ lịch tự động (`status = cancelled`)** khi người tạo lịch (`authorId`) không còn là thành viên `active` của đội hoặc không còn giữ vai trò `captain` / `vice` (bị hạ quyền xuống `member`/`treasurer`, tự rời đội `leave`, hoặc bị mời khỏi đội `remove`).
- **Cơ chế bảo vệ kép:**
  1. **Tại thời điểm Worker thực thi (`publishPostSchedule`):** Trong cùng một transaction sau khi claim lịch (`status: 'scheduled' -> 'cancelled'`), hệ thống kiểm tra `team_members` của `schedule.authorId` tại `schedule.teamId`. Nếu không thoả `status = 'active'` và `role IN ('captain', 'vice')`, worker **không tạo bài kèo**, giữ nguyên trạng thái lịch là `cancelled` và kết thúc job (`{ published: false, nextAt: null }`).
  2. **Tại thời điểm thay đổi nhân sự (`remove` / `leave` / `changeRole`):** Chủ động huỷ các lịch `scheduled` của thành viên vừa mất quyền và gỡ job khỏi hàng đợi BullMQ.

### 0.3. Chính sách thu hồi phiên Chat Realtime (`match:{matchId}`)
- Khi thành viên rời đội (`leave`) hoặc bị loại khỏi đội (`remove`), hệ thống lập tức ngắt kết nối Socket.IO (`disconnectSockets(true)`) và đưa các socket của người dùng đó ra khỏi phòng đội/trận để chặn nhận tin nhắn mới (`chat.message`).
- Mỗi kết nối Socket.IO đặt bộ hẹn giờ theo hạn `exp` của JWT access token; ngay khi token hết hạn, server phát `auth:error` (`{ code: 'token_expired' }`) và ngắt kết nối để buộc client xác thực lại.

---

## US-M5-01: Kèo của tôi & Hẹn lịch đăng kèo (Màn 2, 10)

### User Story
- **As a** Đội trưởng hoặc Đội phó (`captain` / `vice`),
- **I want** chọn đăng kèo ngay hoặc hẹn lịch tự động đăng kèo (một lần hoặc lặp hàng tuần) trên Màn 2, đồng thời xem/huỷ các kèo và lịch đăng trên Màn 10,
- **So that** tôi theo dõi nhanh các đội đang xin nhận kèo và không phải thao tác đăng lại kèo cố định mỗi tuần.

### API & Dữ liệu liên quan
- `GET /v1/me/posts?status={open|matched|closed}&cursor=&limit=`: Lấy danh sách kèo do tài khoản hiện tại tạo.
- `GET /v1/teams/:teamId/post-schedules`: Lấy danh sách lịch hẹn đăng kèo của đội (sắp xếp theo `scheduledAt asc`).
- `POST /v1/teams/:teamId/post-schedules`: Tạo lịch hẹn đăng kèo (`scheduledAt`, `repeatWeekly`, payload kèo).
- `PATCH /v1/teams/:teamId/post-schedules/:scheduleId`: Cập nhật lịch hẹn đang ở trạng thái `scheduled`.
- `DELETE /v1/teams/:teamId/post-schedules/:scheduleId`: Huỷ lịch hẹn (`status = cancelled`, gỡ job BullMQ `post-schedule-{id}-{scheduledAtMs}`).
- Worker job `postSchedulePublish`: Claim nguyên tử bản ghi `post_schedules`, kiểm tra quyền `captain`/`vice` còn hiệu lực của `authorId`, xử lý misfire nếu quá giờ đá, tạo bản ghi `posts` mới trong transaction; nếu `repeatWeekly = true` thì cộng thêm 7 ngày vào `scheduledAt`, `startAt`, `endAt` cho kỳ kế tiếp với `jobId` riêng theo mốc thời gian (`post-schedule-{id}-{nextAtMs}`).

### Tiêu chí nghiệm thu (Acceptance Criteria - BDD)

#### AC1.1: Xem danh sách "Kèo của tôi" theo 3 tab Đang mở, Lịch đăng và Đã chốt (Màn 10 - Happy Path)
- **Given** người dùng đã đăng nhập, có ít nhất 1 kèo đang mở (`status = open`), 1 lịch hẹn đăng kèo (`status = scheduled`), và 1 kèo đã chốt (`status = matched`),
- **When** người dùng mở màn **Cá nhân & cài đặt** (Màn 23) → bấm **"Kèo của tôi"** để vào Màn 10 (`MyPostsScreen`),
- **Then** hệ thống hiển thị thanh điều hướng trên cùng với nút quay lại `"Bảng tin"`, tiêu đề `"Kèo của tôi"`, nút tròn `+` (`aria-label="Đăng kèo mới"`) ở góc phải trên, và thanh phân đoạn 3 tab: `"Đang mở"`, `"Lịch đăng"`, `"Đã chốt"`.
- **And** ở tab `"Đang mở"`, thẻ kèo hiển thị loại kèo (`PostTypeBadge`), khung giờ đá (`Fmt.slot`), tên sân + khu vực, và nút `"N đội muốn nhận · So sánh"` (bấm vào mở Màn 11; bấm vào thân thẻ mở Màn 14).
- **And** khi chuyển sang tab `"Lịch đăng"`, ứng dụng gọi `GET /v1/teams/:teamId/post-schedules` và hiển thị danh sách lịch hẹn kèm thông tin kèo, giờ đăng dự kiến, nhãn lặp tuần và nút `"Huỷ lịch"`.
- **And** khi chuyển sang tab `"Đã chốt"`, hệ thống gọi `GET /v1/me/posts?status=matched` và hiển thị danh sách các kèo đã chốt.

#### AC1.2: Trạng thái màn trống (Empty State) trên màn Kèo của tôi
- **Given** người dùng chưa có dữ liệu ở từng tab trên Màn 10,
- **When** người dùng mở lần lượt các tab `"Đang mở"`, `"Lịch đăng"`, `"Đã chốt"`,
- **Then** hệ thống hiển thị thông báo trống tiếng Việt rõ nghĩa tương ứng (`"Bạn chưa có kèo nào đang mở"`, `"Chưa có lịch hẹn đăng kèo nào"`, `"Chưa có kèo nào đã chốt"`), hỗ trợ kéo xuống để làm mới (`RefreshIndicator`).

#### AC1.3: Chọn "Thời điểm đăng" (Đăng ngay / Hẹn lịch) trên Màn 2 và tạo lịch hẹn hợp lệ
- **Given** người dùng có vai trò `captain` hoặc `vice` đang ở Màn 2 (`PostCreateScreen`),
- **When** người dùng chuyển mục **"Thời điểm đăng"** từ `"Đăng ngay"` sang `"Hẹn lịch"`, chọn thời điểm đăng ở tương lai (`scheduledAt < startAt`) và bật/tắt công tắc `"Lặp lại hàng tuần"`, sau đó bấm nút gửi,
- **Then** ứng dụng gọi `POST /v1/teams/:teamId/post-schedules` và hệ thống trả về HTTP `201 Created` kèm `PostScheduleDto` (`status = scheduled`), đồng thời xếp job `post-schedule-{id}-{scheduledAtMs}` (không chứa dấu `:`) vào hàng đợi BullMQ.

#### AC1.4: Tự động đăng kèo khi đến giờ hẹn & Xử lý trễ giờ (Misfire)
- **Given** một lịch đăng kèo có `status = scheduled` và `scheduledAt <= now`,
- **When** worker chạy `publishPostSchedule` cho `scheduleId`,
- **Then** trong cùng một database transaction:
  - Claim bản ghi bằng `updateMany({ where: { id, status: 'scheduled', scheduledAt: { lte: now } }, data: { status: 'cancelled' } })` để chống 2 worker đăng trùng bài.
  - Nếu `now < startAt`: Tạo kèo mới (`posts`); nếu `repeatWeekly = false` thì giữ `status = cancelled` và lưu `publishedPostId = post.id`; nếu `repeatWeekly = true` thì cập nhật lại `status = scheduled`, dời `scheduledAt`, `startAt`, `endAt` sang tuần kế tiếp (+7 ngày) và xếp job BullMQ cho kỳ mới.
  - Nếu worker chạy trễ khi đã qua giờ bóng lăn (`startAt <= now` - misfire): lịch một lần sẽ hết hạn (`status = cancelled`, không tạo bài); lịch lặp tuần sẽ tự nhảy qua các kỳ bị lỡ tới kỳ tương lai gần nhất (`+ N * 7 ngày`) mà không quăng lỗi retry vô hạn.

#### AC1.5: Sửa, Huỷ lịch hẹn và Tự động huỷ khi tác giả mất quyền đội (Security Blocker #4)
- **Given** lịch đăng kèo đang ở trạng thái `scheduled` thuộc đội của người dùng (`captain`/`vice`),
- **When** gọi `PATCH` hoặc `DELETE /v1/teams/:teamId/post-schedules/:scheduleId`,
- **Then** hệ thống cập nhật hoặc đổi `status = cancelled`, gỡ job BullMQ cũ (`post-schedule-{id}-{oldScheduledAtMs}`) và trả về HTTP `200` (khi sửa) hoặc `204 No Content` (khi huỷ).
- **Given** một Phó đội (`vice`) tạo lịch đăng lặp tuần, sau đó bị Đội trưởng hạ quyền xuống `member` hoặc bị mời rời đội,
- **When** đến giờ `scheduledAt` và worker chạy `publishPostSchedule`,
- **Then** kiểm tra `teamMember` của `authorId` không còn thoả `status = 'active'` + `role IN ('captain', 'vice')`, lịch bị chuyển sang `cancelled` và **tuyệt đối không tạo bài đăng mới**.

#### AC1.6: Edge Cases & Phân quyền lịch đăng
- **Given** người dùng gửi `scheduledAt <= now`,
- **When** gọi tạo hoặc sửa lịch đăng,
- **Then** hệ thống từ chối với HTTP `400 Bad Request`, mã lỗi `schedule_in_past`, thông báo `"Giờ đăng phải ở tương lai"`.
- **Given** người dùng chỉ có vai trò `member` hoặc `treasurer` (không phải `captain`/`vice`),
- **When** gọi `POST`, `PATCH` hoặc `DELETE /v1/teams/:teamId/post-schedules`,
- **Then** hệ thống chặn bằng `@TeamRoles('captain', 'vice')` và trả về HTTP `403 Forbidden`.

---

## US-M5-02: Bình luận & Cảm xúc trên kèo + Danh sách cảm xúc (Màn 1, 14, 24)

### User Story
- **As a** Cầu thủ đã đăng nhập,
- **I want** thả 5 loại cảm xúc (Thích, Tim, Đỉnh, Haha, Tiếc), viết/xoá bình luận trên kèo và xem danh sách những người đã thả cảm xúc theo từng loại,
- **So that** tôi tương tác với cộng đồng, hỏi thêm thông tin về kèo trước khi nhận và biết ai đang quan tâm tới kèo.

### API & Sự kiện Realtime liên quan
- `PUT /v1/posts/:postId/reaction` (`{ kind: 'like' | 'love' | 'fire' | 'haha' | 'sad' }`): Đặt hoặc đổi cảm xúc của tôi trên kèo.
- `DELETE /v1/posts/:postId/reaction`: Gỡ cảm xúc của tôi trên kèo.
- `GET /v1/posts/:postId/reactions?kind=&cursor=&limit=`: Lấy tổng số lượt theo từng loại (`counts`), cảm xúc hiện tại của tôi (`myKind`), và danh sách người thả (`items`, phân trang cursor).
- `POST /v1/posts/:postId/comments` (`{ body }`): Gửi bình luận mới (1–1.000 ký tự sau khi trim).
- `GET /v1/posts/:postId/comments?cursor=&limit=`: Danh sách bình luận mới nhất trước (phân trang cursor).
- `DELETE /v1/posts/:postId/comments/:commentId`: Xoá bình luận (chỉ tác giả bình luận hoặc tác giả bài kèo `post.authorId`).
- Socket.IO room `post:{postId}`: Phát sự kiện `comment.created`, `comment.deleted`, `reaction.changed`.

### Tiêu chí nghiệm thu (Acceptance Criteria - BDD)

#### AC2.1: Thả, đổi và gỡ cảm xúc trên kèo (Màn 1, 14 - Happy Path)
- **Given** người dùng đang xem thẻ kèo trên Bảng tin (Màn 1) hoặc Chi tiết kèo (Màn 14) với icon tim và bình luận đúng theo bản vẽ (không dùng ký tự văn bản `♡` / `◯`) và chưa thả cảm xúc nào (`myKind = null`),
- **When** người dùng bấm nhanh vào nút cảm xúc mặc định (`"Thích"`),
- **Then** ứng dụng gọi `PUT /v1/posts/:postId/reaction` với `kind = like`, nút chuyển sang trạng thái đã chọn màu xanh (`AppColors.primary`) kèm biểu tượng và nhãn `"Thích"`, số đếm cảm xúc tăng thêm 1.
- **When** người dùng nhấn giữ (long press) vào nút cảm xúc để mở thanh chọn 5 cảm xúc (`Thích`, `Tim`, `Đỉnh`, `Haha`, `Tiếc`) và chọn `"Đỉnh"`,
- **Then** ứng dụng gọi `PUT /v1/posts/:postId/reaction` với `kind = fire`, cập nhật cảm xúc sang `"Đỉnh"` mà không làm tăng tổng số người thả cảm xúc.
- **When** người dùng bấm lại vào nút cảm xúc đang được chọn,
- **Then** ứng dụng gọi `DELETE /v1/posts/:postId/reaction`, gỡ cảm xúc của người dùng và giảm số đếm đi 1.

#### AC2.2: Xem màn Danh sách cảm xúc và lọc theo tab (Màn 24)
- **Given** một kèo có nhiều người thả các cảm xúc khác nhau,
- **When** người dùng bấm vào dòng tóm tắt số lượt cảm xúc trên kèo,
- **Then** ứng dụng mở Màn 24 (`ReactionsScreen`) với tiêu đề `"Cảm xúc"`, nút quay lại `"Quay lại"`, thanh chip lọc gồm `"Tất cả"` và 5 loại cảm xúc kèm số đếm từng loại.
- **When** người dùng chọn một chip cảm xúc cụ thể (ví dụ `"Đỉnh"`),
- **Then** ứng dụng gọi `GET /v1/posts/:postId/reactions?kind=fire` và chỉ hiển thị những người đã thả `"Đỉnh"`.
- **And** nếu tab đang chọn chưa có ai thả cảm xúc, màn hình hiển thị `"Chưa có cảm xúc nào"`.
- **And** khi cuộn xuống cuối danh sách (còn `nextCursor`), ứng dụng tự động tải trang tiếp theo (`_loadMore`).

#### AC2.3: Xem, gửi và xoá bình luận (Màn 14 / Bottom Sheet Bình luận)
- **Given** người dùng mở phần bình luận của một kèo,
- **When** danh sách đang tải lần đầu, hiển thị vòng xoay loading; nếu kèo chưa có bình luận nào, hiển thị `"Chưa có bình luận nào"`.
- **When** người dùng nhập nội dung hợp lệ (1–1.000 ký tự, sau khi `trim()` không rỗng) vào ô `"Viết bình luận..."` và bấm `"Gửi"`,
- **Then** nút `"Gửi"` chuyển sang trạng thái loading và khoá bấm lặp (`_sending = true`); sau khi `POST /v1/posts/:postId/comments` trả về thành công, bình luận mới chèn lên đầu danh sách, ô nhập được xoá trắng.
- **Given** người dùng là tác giả của bình luận (`comment.userId === me.id`) hoặc là tác giả đã đăng bài kèo đó (`post.authorId === me.id`, bao gồm cả `captain` hoặc `vice` đã tạo kèo),
- **When** nhìn vào bình luận đó,
- **Then** hiển thị nút `"Xóa"` màu đỏ (`AppColors.red`, vùng bấm tối thiểu 44×44px); khi bấm `"Xóa"`, gọi `DELETE /v1/posts/:postId/comments/:commentId`, xoá bình luận khỏi danh sách và hiện toast `"Đã xóa bình luận"`.

#### AC2.4: Chặn xoá bình luận trái quyền & lỗi mạng (Edge Cases)
- **Given** người dùng A không phải người viết bình luận và không phải tác giả bài kèo (`post.authorId`),
- **When** người dùng A xem bình luận của người dùng B trên UI, nút `"Xóa"` bị ẩn; nếu cố tình gọi API `DELETE /v1/posts/:postId/comments/:commentId`,
- **Then** backend trả về HTTP `403 Forbidden` với mã `comment_delete_forbidden` và thông báo `"Bạn không có quyền xoá bình luận này"`.
- **Given** kết nối mạng bị ngắt khi người dùng gửi bình luận hoặc đổi cảm xúc,
- **When** API trả lỗi,
- **Then** ứng dụng mở khoá nút gửi, giữ nguyên nội dung trong ô nhập bình luận để người dùng không phải gõ lại, và hiện toast lỗi `"Không gửi được bình luận"` hoặc `"Không cập nhật được cảm xúc"`.

---

## US-M5-03: Nhắn tin (Chat) realtime giữa hai đội trong trận (Màn 9, 13, 17, 18, 21, 22)

### User Story
- **As a** Thành viên đang hoạt động (`active`) của một trong hai đội tham gia trận đấu (`homeTeam` hoặc `awayTeam`),
- **I want** mở phòng chat từ chi tiết lịch hoặc màn kết quả trận để nhắn tin trực tiếp theo thời gian thực với đội đối thủ (kèm gợi ý trả lời nhanh và thẻ thông tin trận đấu ghim đầu màn),
- **So that** hai đội dễ dàng thống nhất vị trí sân, màu áo, đổi giờ hoặc báo đến muộn mà không cần chuyển sang ứng dụng chat bên ngoài.

### API & Sự kiện Realtime liên quan
- `GET /v1/matches/:matchId/messages?cursor=&limit=`: Lấy lịch sử tin nhắn của trận đấu (mới nhất trước, phân trang cursor).
- `POST /v1/matches/:matchId/messages` (`{ body }`): Gửi tin nhắn mới trong trận đấu (giới hạn 30 tin/phút, độ dài 1–1.000 ký tự).
- Socket.IO `/v1/socket` — sự kiện `match:join` / `match:leave` cho room `match:{matchId}` và phát sự kiện `chat.message` kèm `{ matchId, message }` (client tự chuẩn hoá bỏ trường `null` trước khi parse DTO).
- *(Lưu ý phạm vi M5/M6 đã chốt với PM: Nút `"Chốt kèo"` và trạng thái `"Đã xem"` trên Màn 21 được chuyển sang Backlog M6).*

### Tiêu chí nghiệm thu (Acceptance Criteria - BDD)

#### AC3.1: Mở màn hình Chat và xem thẻ thông tin trận ghim đầu trang (Happy Path)
- **Given** hai đội đã chốt kèo tạo thành một trận đấu (`matchId`) và người dùng là thành viên `active` của một trong hai đội (`captain`, `vice`, `treasurer`, hoặc `member`),
- **When** người dùng bấm vào thẻ `"Nhắn tin với đội bạn"` từ Chi tiết lịch (Màn 18) hoặc nút `"Nhắn tin"` từ màn Kết quả trận (Màn 17) để mở Màn 21 (`ChatScreen`),
- **Then** ứng dụng tham gia phòng Socket.IO `match:{matchId}`, hiển thị nút quay lại `"Trận"` (không bị rớt dòng), tên đội đối thủ trên thanh tiêu đề, thẻ thông tin trận đấu ghim phía trên (giờ đá, sân, tỷ lệ kèo/trạng thái trận), danh sách tin nhắn và dải 3 chip gợi ý nhanh: `"Gửi vị trí sân"`, `"Đổi giờ?"`, `"Đến muộn 10 phút"`.
- **And** nếu trận đấu chưa có tin nhắn nào, hiển thị trạng thái trống hướng dẫn bắt đầu cuộc trò chuyện.

#### AC3.2: Gửi tin nhắn văn bản, bấm chip gợi ý nhanh và nhận tin nhắn Realtime
- **Given** người dùng đang ở Màn 21 và trận đấu chưa bị huỷ (`status != cancelled`),
- **When** người dùng nhập tin nhắn vào ô nhập và bấm icon gửi (hoặc bấm vào một chip gợi ý nhanh như `"Đến muộn 10 phút"`),
- **Then** ứng dụng gọi `POST /v1/matches/:matchId/messages`, bong bóng tin nhắn của người gửi hiện bên phải (màu `AppColors.primary`, chữ trắng, bo góc nhọn ở đuôi bong bóng theo bản vẽ); tin nhắn của đội bạn hiện bên trái kèm tên người gửi, avatar và thời gian.
- **When** thành viên đội đối thủ gửi một tin nhắn mới trong cùng `matchId`,
- **Then** thông qua sự kiện Socket.IO `chat.message`, tin nhắn mới tự động xuất hiện ngay trên màn hình của người dùng mà không cần tải lại trang và không bị trùng lặp (`id` deduplication).

#### AC3.3: Thu hồi quyền nhận Chat Realtime khi rời đội / bị loại hoặc hết hạn JWT (Security Blocker #3)
- **Given** thành viên A đang mở kết nối Socket.IO và đã join vào phòng `match:{matchId}`,
- **When** thành viên A tự rời đội (`leave`) hoặc bị Đội trưởng mời ra khỏi đội (`remove`),
- **Then** backend lập tức gọi `evictFromTeam` ngắt kết nối socket của thành viên A (`disconnectSockets(true)`), khiến thành viên A không còn nhận được bất kỳ sự kiện `chat.message` nào phát sinh sau đó trong trận đấu; đồng thời nếu gọi `match:join` hoặc REST `GET/POST /v1/matches/:matchId/messages` sẽ bị từ chối (`{ ok: false }` / HTTP `403 Forbidden`).
- **Given** kết nối Socket.IO của người dùng có JWT access token chạm mốc hết hạn (`exp`),
- **When** bộ đếm thời gian `expiryTimer` trên gateway kích hoạt,
- **Then** server phát sự kiện `auth:error` (`{ code: 'token_expired' }`) và chủ động ngắt kết nối socket (`client.disconnect(true)`).

#### AC3.4: Chế độ chỉ đọc khi trận đấu đã huỷ (`status = cancelled`)
- **Given** trận đấu đã chuyển sang trạng thái huỷ (`status = cancelled`),
- **When** người dùng mở Màn 21 (`ChatScreen`) của trận đấu đó,
- **Then** giao diện ẩn dải chip gợi ý nhanh và thay ô nhập tin nhắn bằng thanh thông báo chỉ đọc (`"Trận đấu đã huỷ — chỉ có thể xem lại tin nhắn cũ"`).
- **And** nếu cố tình gọi thẳng API `POST /v1/matches/:matchId/messages`, backend trả về HTTP `409 Conflict` (`match_cancelled`: `"Trận đã huỷ, không thể gửi tin nhắn"`).

#### AC3.5: Trạng thái lỗi mạng và tải thêm lịch sử tin nhắn (Pagination)
- **Given** cuộc trò chuyện có hơn 30 tin nhắn,
- **When** người dùng cuộn ngược lên phía trên để xem tin nhắn cũ (`extentAfter < 160`),
- **Then** ứng dụng gọi `GET /v1/matches/:matchId/messages?cursor={nextCursor}` để nối thêm tin nhắn cũ mà không làm giật vị trí cuộn.
- **Given** thiết bị mất mạng khi mở màn Chat lần đầu,
- **When** API tải tin nhắn thất bại (`_failed = true`),
- **Then** màn hình hiển thị thông báo lỗi kèm nút `"Thử lại"` để tải lại danh sách tin nhắn.

---

## US-M5-04: Hồ sơ cá nhân, Thống kê cầu thủ & Cài đặt thông báo (Màn 23)

### User Story
- **As a** Người dùng đã đăng nhập,
- **I want** xem và chỉnh sửa hồ sơ cầu thủ của mình, xem thống kê cá nhân (số trận, bàn thắng, kiến tạo, MVP), truy cập nhanh Kèo của tôi / Lịch sử đặt sân / Quỹ của tôi / Danh hiệu, bật/tắt từng nhóm thông báo và đăng xuất tại màn Cá nhân & cài đặt,
- **So that** thông tin thi đấu của tôi luôn chính xác và tôi kiểm soát được các loại thông báo muốn nhận.

### API & Dữ liệu liên quan
- `GET /v1/me`: Trả về thông tin cá nhân (`id`, `email`, `name`, `avatarUrl`, `position`, `shirtNumber`, `area`, `profileCompleted`), thống kê tích luỹ (`stats: { matches, goals, assists, mvps }`) và danh sách đội tham gia (`teams`).
- `PATCH /v1/me`: Cập nhật `name`, `position`, `shirtNumber`, `area`. *(Cập nhật `avatarUrl` chuyển sang M6).*
- `GET /v1/me/notification-settings` & `PATCH /v1/me/notification-settings`: Đọc và cập nhật 3 cờ `matchUpdates` (Cập nhật kèo & trận), `teamActivity` (Hoạt động đội & quỹ), `community` (Bình luận & cảm xúc).
- `POST /v1/auth/logout`: Thu hồi refresh token hiện tại và xoá phiên đăng nhập trên máy.

### Tiêu chí nghiệm thu (Acceptance Criteria - BDD)

#### AC4.1: Hiển thị đầy đủ Hồ sơ, Thống kê, Đội của tôi và Hoạt động (Happy Path)
- **Given** người dùng đã đăng nhập và có dữ liệu thống kê từ các trận đã kết thúc (`status = finished`),
- **When** người dùng mở Màn 23 (`MeScreen`),
- **Then** màn hình hiển thị:
  - Thanh tiêu đề có nút quay lại `"Bảng tin"` và nút `"Sửa"` ở góc phải trên.
  - Thẻ hồ sơ cầu thủ: Avatar, Tên, Vị trí sở trường, Số áo, Khu vực.
  - Khối thống kê 4 chỉ số: **Trận** (`matches` chỉ tính trận `finished`), **Bàn thắng** (`goals`), **Kiến tạo** (`assists`), **MVP** (`mvps`).
  - Nhóm **Đội của tôi**: Danh sách các đội kèm khiên đội (`TeamCrest`), tên đội và vai trò (`Đội trưởng`, `Đội phó`, `Thủ quỹ`, `Thành viên`).
  - Nhóm **Hoạt động**: Đầy đủ 4 lối vào bấm được: `"Kèo của tôi"` (mở Màn 10), `"Lịch sử đặt sân"`, `"Quỹ của tôi"` (mở Màn 6) và `"Danh hiệu"` (mở Màn 7).

#### AC4.2: Chỉnh sửa hồ sơ cầu thủ và Khu vực mặc định
- **Given** người dùng đang ở Màn 23,
- **When** bấm nút `"Sửa"` ở góc phải trên (hoặc bấm vào dòng `"Khu vực"`), thay đổi Tên, Vị trí, Số áo (0–99) hoặc Khu vực rồi bấm lưu,
- **Then** ứng dụng gọi `PATCH /v1/me`, cập nhật lại state `authControllerProvider` với dữ liệu mới và hiển thị ngay trên Màn 23.
- **And** nếu người dùng xoá trống tên hoặc nhập số áo ngoài khoảng hợp lệ (0–99), form hiển thị cảnh báo/chặn nhập sai định dạng.

#### AC4.3: Bật / Tắt cài đặt thông báo
- **Given** người dùng đang xem khối **Thông báo** trên Màn 23,
- **When** màn hình tải xong, 3 công tắc (`Switch`) hiển thị đúng trạng thái từ `GET /v1/me/notification-settings` (mặc định tạo mới đều là `true`).
- **When** người dùng gạt bật hoặc tắt một công tắc (ví dụ tắt `"Bình luận & cảm xúc"`),
- **Then** ứng dụng gọi `PATCH /v1/me/notification-settings` với `{ community: false }` và lưu trạng thái mới; nếu gọi API lỗi (mất mạng), công tắc hoàn tác về trạng thái cũ và hiện toast báo lỗi.

#### AC4.4: Đăng xuất có xác nhận
- **Given** người dùng bấm vào dòng `"Đăng xuất"` (chữ màu đỏ destructive) ở cuối Màn 23,
- **When** hộp thoại xác nhận `"Đăng xuất?"` hiện ra với 2 nút `"Huỷ"` và `"Đăng xuất"`,
- **Then** nếu bấm `"Huỷ"`, hộp thoại đóng lại và người dùng vẫn ở Màn 23; nếu bấm `"Đăng xuất"`, ứng dụng gọi `POST /v1/auth/logout`, xoá token trong `flutter_secure_storage` và điều hướng về màn Đăng nhập (Màn 12).

---

## US-M5-05: Tải ảnh lên kho S3 (Quarantine & Re-encode) + Ảnh trong kèo (Màn 1, 2, 14)

### User Story
- **As a** Người dùng đăng kèo hoặc đính kèm ảnh,
- **I want** chọn ảnh từ thiết bị, tải lên vùng cách ly (quarantine) qua Presigned URL, để hệ thống kiểm tra nội dung thật + chuyển đổi sang WebP an toàn trước khi hiển thị công khai tối đa 4 ảnh trong bài đăng kèo,
- **So that** bài đăng kèo trực quan hơn mà vẫn đảm bảo an toàn bảo mật (chống giả mạo MIME, chống tràn kho lưu trữ và không gặp lỗi 403 đọc bucket trực tiếp).

### API & Cơ chế bảo mật liên quan (Security Blockers #1 & #2)
- `POST /v1/media/uploads` (`{ purpose: 'post' | 'avatar' | 'receipt', contentType, size }`):
  - Giới hạn tần suất: tối đa `20 URL / phút`.
  - Giới hạn quota theo tài khoản: tối đa `50 MB / ngày UTC` (`DAILY_UPLOAD_QUOTA_BYTES = 52.428.800` bytes), theo dõi trong bảng `media_uploads` (`isolationLevel: Serializable`).
  - Tạo bản ghi `media_uploads` (`status = pending`, `expiresAt = now + 300s`) và cấp presigned PUT URL trỏ vào khoá cách ly `quarantine/{uuid}.upload`, đồng thời trả về `key = public/{uuid}.webp` và `publicUrl = {MEDIA_PUBLIC_URL}/{uuid}`.
- Bước **Finalize & Re-encode** (khi gắn `mediaKeys` vào `POST /v1/teams/:teamId/posts` hoặc `POST/PATCH .../post-schedules`):
  - Kiểm tra bản ghi `media_uploads` thuộc đúng `ownerId = userId`, `status = pending`, chưa hết hạn (`expiresAt > now`).
  - Đọc byte thực từ `quarantine/{uuid}.upload`, đối chiếu `byteLength === expectedSize <= 10MB`, dùng thư viện `sharp` giải mã ảnh thật (kiểm tra magic bytes, chặn decompression bomb với `MAX_IMAGE_PIXELS = 40.000.000`), tự xoay theo EXIF và **re-encode sang WebP (`quality: 85`)**.
  - Ghi file WebP sạch vào `public/{uuid}.webp`, xoá object `quarantine/{uuid}.upload`, cập nhật `status = ready`, `finalizedAt` và `referencedAt`. Nếu giải mã thất bại, xoá ngay file quarantine, đánh dấu `status = rejected` và trả lỗi HTTP `415`.
- `GET /v1/media/public/:id`: Endpoint công khai phục vụ ảnh đã ở trạng thái `ready` (`Content-Type: image/webp`) kèm header bảo mật `X-Content-Type-Options: nosniff` (khắc phục triệt để lỗi `403 Forbidden` khi app đọc trực tiếp từ bucket SeaweedFS private).
- Worker job `mediaCleanup` (chạy định kỳ mỗi giờ): Tự động xoá các object S3 (`quarantineKey` và `publicKey`) của các bản ghi `media_uploads` đã quá hạn (`expiresAt <= now`) mà không được bài viết nào tham chiếu (`referencedAt = null`), rồi đổi `status = expired`.

### Tiêu chí nghiệm thu (Acceptance Criteria - BDD)

#### AC5.1: Xin Presigned URL, tải ảnh lên vùng Quarantine và Finalize sang WebP (Happy Path)
- **Given** dịch vụ kho ảnh S3 đang hoạt động, người dùng chưa vượt quota 50MB/ngày và chọn một file ảnh thật định dạng `image/jpeg`, `image/png`, `image/webp` hoặc `image/heic` có dung lượng `<= 10MB` (`10.485.760` bytes),
- **When** ứng dụng gọi `POST /v1/media/uploads` rồi dùng HTTP `PUT` đẩy byte ảnh lên `uploadUrl` với đúng header `Content-Type` và `Content-Length`, sau đó gửi `key` (`public/{uuid}.webp`) vào `mediaKeys` khi tạo kèo,
- **Then** hệ thống xác minh nội dung ảnh bằng `sharp`, re-encode sang WebP, xoá file quarantine, chuyển trạng thái `media_uploads` sang `ready` + gán `referencedAt`, và trả về `PostDto.media` có `url` tải ảnh thành công (`HTTP 200`, `Content-Type: image/webp`, `X-Content-Type-Options: nosniff`).

#### AC5.2: Hiển thị ảnh đính kèm trên Bảng tin (Màn 1) và Chi tiết kèo (Màn 14)
- **Given** người dùng đã đăng kèo kèm từ 1 đến 4 ảnh trên Màn 2 (`PostCreateScreen`),
- **When** xem kèo đó trên Bảng tin (Màn 1) hoặc mở Chi tiết kèo (Màn 14),
- **Then** kèo hiển thị khung ảnh theo đúng số lượng ảnh đính kèm; khi ảnh đang tải hiển thị placeholder nền xám, khi lỗi ảnh hiển thị ô báo lỗi gọn mà không vỡ bố cục.

#### AC5.3: Chặn file giả mạo MIME / nội dung độc hại (Security Blocker #1)
- **Given** kẻ tấn công xin URL upload với `contentType: 'image/jpeg'`, nhưng `PUT` nội dung là mã HTML/script, file thực thi, file hỏng hoặc ảnh vượt quá `40 Megapixels` (`MAX_IMAGE_PIXELS`),
- **When** gọi tạo kèo hoặc lịch đăng để kích hoạt bước `finalize`,
- **Then** `sharp` từ chối giải mã, hệ thống lập tức xoá object trong `quarantine/`, cập nhật bản ghi `media_uploads` thành `status = rejected`, và trả về HTTP `415 Unsupported Media Type` (`invalid_image_content`: `"File tải lên không phải ảnh hợp lệ"`).
- **And** khi gọi `GET /v1/media/public/:id` với ID của file chưa `ready` hoặc đã bị `rejected`, hệ thống trả về HTTP `404 Not Found` (`media_not_found`).

#### AC5.4: Chặn vượt Quota dung lượng ngày, file quá 10MB, key người khác & Dọn rác tự động (Security Blocker #2)
- **Given** người dùng truyền file không thuộc 4 MIME ảnh cho phép hoặc `size > 10MB`,
- **When** gọi `POST /v1/media/uploads`,
- **Then** hệ thống từ chối ngay với HTTP `415 Unsupported Media Type` (`media_type_not_allowed`) hoặc HTTP `413 Payload Too Large` (`media_too_large`: `"Ảnh tối đa 10MB"`).
- **Given** tổng `expectedSize` các lần xin upload trong ngày UTC của cùng một `userId` cộng với `size` mới vượt quá `50MB`,
- **When** gọi `POST /v1/media/uploads`,
- **Then** hệ thống từ chối với HTTP `429 Too Many Requests` (`media_daily_quota_exceeded`: `"Đã dùng hết quota tải ảnh hôm nay"`).
- **Given** người dùng truyền trùng key trong `mediaKeys` hoặc truyền key của người dùng khác / key chưa tải xong,
- **When** gọi tạo kèo,
- **Then** backend trả về HTTP `400 Bad Request` (`duplicate_media_key` / `media_not_uploaded`) hoặc HTTP `403 Forbidden` (`media_forbidden`).
- **Given** một bản ghi `media_uploads` đã quá hạn 5 phút (`expiresAt <= now`) mà không được gắn vào kèo nào (`referencedAt = null`),
- **When** job BullMQ `mediaCleanup` chạy,
- **Then** hệ thống xoá cả object `quarantineKey` và `publicKey` trên S3 và đổi trạng thái bản ghi sang `expired`.

---

## 7. Ma trận kiểm thử trạng thái giao diện & mạng xuyên suốt M5

Để đảm bảo Definition of Done (DoD) trước khi nghiệm thu và merge nhánh `m5-cong-dong`, QA và Dev đối chiếu bảng kiểm tra nhanh dưới đây trên tất cả các màn M5 (Màn 1, 2, 10, 14, 21, 23, 24):

| Hạng mục kiểm tra | Tiêu chuẩn nghiệm thu |
|---|---|
| **Trạng thái Đang tải (Loading)** | Mọi danh sách (Kèo của tôi, Lịch đăng, Bình luận, Cảm xúc, Tin nhắn chat) đều hiện `CircularProgressIndicator` khi tải lần đầu và ở cuối danh sách khi phân trang (`_loadingMore`). Nút gửi (Bình luận, Tin nhắn, Lưu hồ sơ, Đăng kèo) bị vô hiệu hoá (`disabled`) trong lúc đang chờ phản hồi API để chống gửi trùng. |
| **Trạng thái Trống (Empty State)** | Hiển thị câu thông báo tiếng Việt rõ nghĩa, căn giữa, màu chữ phụ `AppColors.textSecondary` (`#6E6E73`) khi danh sách 0 phần tử (không hiện màn hình trắng trơn). |
| **Trạng thái Lỗi & Mất mạng (Offline / Error)** | Khi mất mạng hoặc API trả lỗi 5xx/timeout: các màn tải dữ liệu chính có nút `"Thử lại"`; các thao tác ghi (gửi chat, gửi bình luận, thả cảm xúc, xoá bình luận, đổi cài đặt, huỷ lịch) hiện `showToast(..., type: ToastType.error)` bằng tiếng Việt và giữ nguyên dữ liệu người dùng vừa nhập. |
| **Chuẩn giao diện & Vùng bấm** | Không dùng mã màu hard-code ngoài `tokens.dart`; chữ giao diện và dữ liệu mẫu chụp màn hình 100% tiếng Việt có dấu đúng chuẩn UTF-8; các nút hành động (Gửi, Xoá bình luận, Cảm xúc, Quay lại, Sửa hồ sơ) đạt kích thước vùng chạm tối thiểu `44×44px` (`AppSizes.tapTarget`). |
