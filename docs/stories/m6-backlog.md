# Product Backlog Chặng M6: Phát hành & Hoàn thiện giao diện (Sân 7)

- **Phiên bản:** 1.0 | **Ngày cập nhật:** 17/11/2026
- **Người viết:** BA (kiêm PO)
- **Nguồn đối chiếu:** `docs/PLAN.md` (mục 11, 13, 16), `docs/HANDOVER.md` (mục 2), `docs/design/gap-report.md`
- **Phương pháp ưu tiên:** MoSCoW (`Must Have`, `Should Have`, `Could Have`, `Won't Have in M6`)
- **Đơn vị ước lượng:** Story Points (SP, thang Fibonacci 1–2–3–5–8) & Thời gian dự kiến (người-ngày / man-day)

---

## 1. Bảng tổng hợp Backlog M6 & Cờ phụ thuộc anh Duy

| Mã Story | Tên User Story | Nhóm | MoSCoW | Ước lượng | Cần anh Duy (Tài khoản / Tiền / Quyết định) |
|---|---|---|---|---|---|
| **US-M6-01** | Xoá tài khoản người dùng trong app (Account Deletion) | Pháp lý & Store | **Must Have** | 3 SP (~1 ngày) | Không |
| **US-M6-02** | Đăng nhập bằng Apple (Sign in with Apple) | Pháp lý & Store | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Tài khoản Apple Developer ($99 / ~2,5 triệu đ/năm) + cấu hình Apple Service ID / Key |
| **US-M6-03** | Chính sách quyền riêng tư & Điều khoản sử dụng công khai | Pháp lý & Store | **Must Have** | 2 SP (~0,5 ngày) | **CÓ:** Duyệt nội dung pháp lý, thông tin chủ thể liên hệ & tên miền đăng tải |
| **US-M6-04** | Hoàn thiện Push Notification FCM trên Android & iOS | Vận hành & Kỹ thuật | **Must Have** | 3 SP (~1 ngày) | **CÓ:** Tạo Firebase project (miễn phí), cấp `google-services.json`, `GoogleService-Info.plist`, APNs key & `FIREBASE_SERVICE_ACCOUNT` |
| **US-M6-05** | Giám sát lỗi & Crash Reporting với Sentry (App + Backend) | Vận hành & Kỹ thuật | **Must Have** | 3 SP (~1 ngày) | **CÓ:** Tạo project Sentry (gói Free/Developer) & cấp `SENTRY_DSN` |
| **US-M6-06** | Triển khai VPS Production, HTTPS Caddy, R2 & Sao lưu DB tự động | Hạ tầng & Vận hành | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Thuê VPS (~1–5 triệu đ/tháng), mua tên miền (~0,3–1 triệu đ/năm), tài khoản Cloudflare R2 |
| **US-M6-07** | Nén ảnh phía client trước khi tải lên & gắn chọn ảnh vào UI Đăng kèo / Hồ sơ / Quỹ | Hoàn thiện M5 & Hiệu năng | **Must Have** | 5 SP (~1,5 ngày) | Không |
| **US-M6-08** | Đóng gói bản phát hành (Android/iOS) & Chuẩn bị Store Listing | Phát hành Store | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Google Play Console ($25 / ~650k đ một lần), Apple App Store Connect (~2,5 triệu đ/năm), máy Mac hoặc Codemagic để ký iOS |
| **US-M6-09** | Bổ sung API liệt kê lịch đăng kèo & hoàn thiện UI hẹn lịch (Màn 2, 10, 18) | Bù nợ M5 / Gap Nặng-Vừa | **Should Have** | 5 SP (~1,5 ngày) | Không |
| **US-M6-10** | Nối nút "Nhắn tin" từ Màn 9, 13, 22 sang màn Chat (Màn 21) & nút "Hoàn tác" | Bù nợ M2–M5 / Gap Vừa | **Should Have** | 3 SP (~1 ngày) | Không |
| **US-M6-11** | Đóng các mục lệch mức Vừa luồng Bảng tin & Cáp kèo (Màn 1, 2, 11, 14) | Gap Report M0–M4 (Vừa) | **Should Have** | 5 SP (~1,5 ngày) | Không |
| **US-M6-12** | Đóng các mục lệch mức Vừa luồng Đặt sân, Kết quả & Đội bóng (Màn 3, 4, 6, 12, 16, 17, 19, 22) | Gap Report M0–M4 (Vừa) | **Should Have** | 5 SP (~1,5 ngày) | **CÓ:** Chốt quyền thật của Phó đội (Màn 19), thay dữ liệu 12 sân mẫu bằng danh sách sân thật & cấp API key Map tile thương mại (MapTiler/Stadia) |
| **US-M6-13** | Rà soát vùng bấm 44×44px, tương phản AA & trạng thái mất mạng/loading toàn app | Gap xuyên suốt (Vừa) | **Should Have** | 3 SP (~1 ngày) | **CÓ:** Chốt kiểu hiển thị Toast chuẩn trên toàn app |
| **US-M6-14** | Dịch vụ thêm tại sân & tạm tính chia tiền trên màn Đặt sân (Màn 15, 16) | Gap Report M3 (Vừa) | **Could Have** | 3 SP (~1 ngày) | Không (chưa gồm cổng thanh toán cọc online) |
| **US-M6-15** | Cổng thanh toán đặt cọc sân online & Bản giao diện Desktop/Web (Màn 15, D) | Sau M6 (Post-launch) | **Won't Have (M6)** | 13 SP (~4 ngày) | **CÓ:** Xác nhận có làm bản Desktop không; ký hợp đồng cổng thanh toán (PayOS/VNPay/SePay) |

---

## 2. Top 5 User Story M6 nên làm trước (Theo thứ tự ưu tiên)

Để không bị chặn khi duyệt App Store / Google Play và có môi trường chạy thật sớm cho đội kiểm thử, **Top 5 story cần làm ngay đầu M6** là:

1. **US-M6-01 — Xoá tài khoản người dùng (Must Have, 3 SP):** Yêu cầu bắt buộc của cả Apple App Store (Guideline 5.1.1(v)) và Google Play đối với mọi ứng dụng có tạo tài khoản. Không phụ thuộc bên thứ ba, Backend + Frontend làm được ngay.
2. **US-M6-07 — Nén ảnh phía client & nối UI chọn ảnh vào Đăng kèo / Hồ sơ / Chi quỹ (Must Have, 5 SP):** Khép kín luồng media của M5 (backend đã có presigned URL S3 nhưng UI đăng kèo/chi quỹ/avatar cần nối hoàn chỉnh kèm nén ảnh để tiết kiệm dung lượng S3/R2).
3. **US-M6-04 — Hoàn thiện Push Notification FCM thực tế trên thiết bị (Must Have, 3 SP):** Kèo bóng đá phụ thuộc lớn vào thông báo đẩy tức thời (nhận kèo, chốt kèo, nhắc điểm danh, nhắc đóng quỹ). Cần chạy thông suốt ngay khi anh Duy cấp cấu hình Firebase.
4. **US-M6-05 — Tích hợp Sentry theo dõi lỗi & Crash Reporting (Must Have, 3 SP):** Cần gắn trước khi đưa app lên môi trường Beta/VPS để bắt toàn bộ lỗi runtime trên thiết bị thật của người dùng.
5. **US-M6-02 — Đăng nhập bằng Apple / Sign in with Apple (Must Have, 5 SP):** Điều kiện tiên quyết của Apple App Store khi app đã có Google Sign-In; trên màn 12 hiện mới có nhãn placeholder nên cần hoàn thiện cả Backend verify Apple token lẫn Flutter.

---

## 3. Tổng hợp các việc cần anh Duy thực hiện (Tài khoản, Chi phí & Quyết định)

### A. Tài khoản & Chi phí (Cần thanh toán / đăng ký)
1. **Google Play Console:** Đăng ký tài khoản nhà phát triển Android — phí một lần **$25 (~650.000đ)**, xác minh danh tính để tạo ứng dụng `vn.san7.app`.
2. **Apple Developer Program:** Đăng ký tài khoản nhà phát triển iOS — phí **$99/năm (~2.500.000đ/năm)** để mở quyền *Sign in with Apple*, tạo APNs Push Key và đưa app lên TestFlight / App Store.
3. **Hạ tầng máy chủ (VPS + Tên miền + Lưu trữ ảnh):**
   - Thuê **VPS** (Contabo hoặc tương đương, 8GB–16GB RAM) — khoảng **1.000.000đ – 5.000.000đ/tháng** (theo `PLAN.md` mục 16).
   - Mua **Tên miền** (ví dụ `san7.vn` hoặc tương đương) — khoảng **300.000đ – 1.000.000đ/năm**, trỏ DNS `api.<tenmien>` về VPS.
   - Tạo bucket **Cloudflare R2** (hoặc S3 tương thích) và cấp `S3_ENDPOINT`, `S3_PUBLIC_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`.
4. **Máy build iOS (Mac / Codemagic):** Chuẩn bị máy Mac hoặc tài khoản CI/CD **Codemagic** để build và ký file `.ipa` đẩy lên App Store Connect.

### B. Khoá cấu hình dịch vụ miễn phí (Cần tạo trên tài khoản của anh Duy)
1. **Firebase Console:** Tạo project Firebase cho `vn.san7.app`, tải `google-services.json` (Android), `GoogleService-Info.plist` (iOS), gắn APNs key và xuất `FIREBASE_SERVICE_ACCOUNT` (base64 JSON) cho Backend.
2. **Sentry.io:** Tạo project NestJS và Flutter trên Sentry (gói miễn phí), gửi `SENTRY_DSN` cho đội kỹ thuật.
3. **Bản đồ (Map Tiles):** Tạo tài khoản nhà cung cấp tile bản đồ thương mại có gói miễn phí/rẻ (như MapTiler hoặc Stadia Maps) để thay cho tile OpenStreetMap công cộng trước khi mở rộng người dùng.

### C. Quyết định sản phẩm (PO/Sponsor Sign-off)
1. **Dữ liệu sân bóng thật:** Cung cấp danh sách sân bóng thật tại khu vực ra mắt (tên sân, địa chỉ, toạ độ, số sân 7, bảng giá theo khung giờ, SĐT chủ sân) để thay thế 12 sân mẫu trong `seed.ts`.
2. **Chính sách quyền riêng tư & Điều khoản:** Xác nhận tên đơn vị/cá nhân chịu trách nhiệm pháp lý và email hỗ trợ để đưa vào trang Chính sách riêng tư.
3. **Chốt 3 điểm thiết kế trong `gap-report.md`:**
   - Quyền thật của **Phó đội** ở Màn 19: giữ theo code hiện tại (*"tạo lịch, duyệt thành viên"*) hay đổi theo chữ trong bản vẽ (*"đăng kèo, đặt sân"*, thực tế code backend đang cho phép cả hai).
   - Có làm **màn hình Desktop (Màn D)** ở đợt ra mắt này không (Mặc định khuyến nghị: **Không làm ở M6**, tập trung 100% mobile theo `PLAN.md`).
   - Kiểu hiển thị **Toast** hiện tại (`core/widgets/app_toast.dart`) đã đạt yêu cầu của anh Duy chưa.

---

## 4. Chi tiết các User Story theo chuẩn INVEST

---

### US-M6-01: Xoá tài khoản người dùng trong app (Account Deletion)
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không
- **Chuẩn INVEST:** Độc lập (I), Có thể thương lượng cách ẩn danh dữ liệu lịch sử (N), Đem lại quyền kiểm soát dữ liệu và vượt qua kiểm duyệt Store (V), Ước lượng rõ (E), Nhỏ gọn trong 1 sprint (S), Kiểm thử được bằng API & UI (T).

**User Story:**
- **As a** Người dùng đã đăng nhập,
- **I want** yêu cầu xoá vĩnh viễn tài khoản của mình ngay trong màn Cá nhân & cài đặt (Màn 23),
- **So that** thông tin cá nhân của tôi được gỡ khỏi hệ thống khi tôi không còn nhu cầu sử dụng ứng dụng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Hiển thị & cảnh báo xác nhận):**
  - **Given** người dùng đang ở Màn 23 (`MeScreen`),
  - **When** cuộn xuống cuối màn hình dưới nút `"Đăng xuất"`,
  - **Then** hiển thị nút `"Xoá tài khoản"` (màu đỏ cảnh báo); khi bấm vào sẽ mở hộp thoại yêu cầu xác nhận rõ hậu quả: *"Tài khoản, thiết bị và thông tin cá nhân của bạn sẽ bị xoá vĩnh viễn và không thể khôi phục."* kèm nút `"Huỷ"` và `"Xoá vĩnh viễn"`.
- **AC2 (Chặn xoá khi đang là Đội trưởng duy nhất của đội còn thành viên khác):**
  - **Given** người dùng đang là `captain` duy nhất của một đội có từ 2 thành viên `active` trở lên,
  - **When** gọi `DELETE /v1/me`,
  - **Then** backend trả về HTTP `409 Conflict` (`captain_must_transfer`: *"Vui lòng chuyển quyền Đội trưởng hoặc giải tán đội trước khi xoá tài khoản"*).
- **AC3 (Thực thi xoá tài khoản & thu hồi phiên):**
  - **Given** người dùng không bị vướng điều kiện Đội trưởng (hoặc đội chỉ có 1 mình người dùng),
  - **When** xác nhận `"Xoá vĩnh viễn"` (`DELETE /v1/me`),
  - **Then** trong một transaction: thu hồi toàn bộ refresh token, xoá `devices`, `notification_settings`, ẩn danh hoặc xoá bản ghi `users` (giữ toàn vẹn lịch sử trận đấu/quỹ chung của các đội cũ), xoá ảnh thuộc `users/{userId}/` trên S3, xoá token dưới máy và đưa người dùng về Màn 12 (Đăng nhập).

---

### US-M6-02: Đăng nhập bằng Apple (Sign in with Apple)
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Tài khoản Apple Developer ~2,5 triệu đ/năm + cấu hình Sign in with Apple capability)

**User Story:**
- **As a** Người dùng thiết bị iOS (iPhone),
- **I want** đăng nhập nhanh vào Sân 7 bằng tài khoản Apple ID của mình tại Màn 12,
- **So that** tôi vào ứng dụng an toàn, không cần tạo mật khẩu mới và có thể ẩn email cá nhân nếu muốn.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Đăng nhập Apple thành công):**
  - **Given** người dùng mở Màn 12 trên iOS và bấm nút `"Tiếp tục với Apple"`,
  - **When** xác thực Face ID / Touch ID thành công, ứng dụng gửi `identityToken` (và `givenName`, `familyName` ở lần đăng nhập đầu) lên `POST /v1/auth/apple`,
  - **Then** backend xác thực chữ ký JWT với Apple JWKS, tạo hoặc cập nhật bản ghi `users` (cột `apple_sub` unique), trả về cặp `accessToken` + `refreshToken` giống hệt luồng Google Sign-In.
- **AC2 (Hỗ trợ Hide My Email & ghép tài khoản):**
  - **Given** người dùng chọn *"Ẩn email của tôi"* (`privaterelay.appleid.com`) hoặc chỉ cấp tên ở lần đầu tiên,
  - **When** đăng nhập lại ở các lần sau (Apple không gửi lại tên),
  - **Then** backend tìm theo `apple_sub` và giữ nguyên tên hồ sơ người dùng đã lưu, không ghi đè tên thành rỗng.
- **AC3 (Huỷ đăng nhập hoặc token không hợp lệ):**
  - **Given** người dùng bấm huỷ hộp thoại Apple Sign-In hoặc gửi `identityToken` sai/hết hạn,
  - **When** luồng kết thúc,
  - **Then** nếu người dùng tự huỷ thì không báo lỗi đỏ; nếu token không hợp lệ thì backend trả HTTP `401 Unauthorized` với thông báo tiếng Việt `"Xác thực Apple không hợp lệ"`.

---

### US-M6-03: Chính sách quyền riêng tư & Điều khoản sử dụng công khai
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `2 SP` (~0,5 ngày) | **Cần anh Duy:** **CÓ** (Duyệt nội dung văn bản & thông tin liên hệ)

**User Story:**
- **As a** Người dùng mới ở Màn 12 hoặc người dùng đang xem Màn 23,
- **I want** đọc rõ Điều khoản sử dụng và Chính sách quyền riêng tư bằng tiếng Việt ngay trên ứng dụng và qua đường dẫn web công khai,
- **So that** tôi hiểu dữ liệu vị trí, hồ sơ cầu thủ, ảnh tải lên được sử dụng như thế nào trước khi đồng ý sử dụng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (URL công khai cho App Store / Google Play):**
  - **Given** người kiểm duyệt của Apple/Google hoặc người dùng truy cập URL `https://<tenmien>/privacy` và `https://<tenmien>/terms`,
  - **When** mở bằng trình duyệt bất kỳ (không cần đăng nhập),
  - **Then** trang hiển thị đầy đủ nội dung tiếng Việt nêu rõ: dữ liệu thu thập (email, tên, vị trí tìm sân, ảnh tải lên), mục đích sử dụng, không bán dữ liệu cho bên thứ ba, cách yêu cầu xoá tài khoản và thông tin liên hệ.
- **AC2 (Mở từ Màn 12 và Màn 23 trong app):**
  - **Given** người dùng đang ở Màn 12 (dòng *"Bằng việc tiếp tục, bạn đồng ý với Điều khoản và Chính sách quyền riêng tư"*) hoặc ở Màn 23 (Cá nhân & cài đặt),
  - **When** bấm vào liên kết `"Điều khoản"` hoặc `"Chính sách quyền riêng tư"`,
  - **Then** ứng dụng mở nội dung tương ứng (in-app browser hoặc màn đọc tĩnh) mà không bị lỗi đường dẫn chết.

---

### US-M6-04: Hoàn thiện Push Notification FCM trên Android & iOS
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** **CÓ** (Tạo Firebase project, cấp `google-services.json`, `GoogleService-Info.plist`, APNs key & `FIREBASE_SERVICE_ACCOUNT`)

**User Story:**
- **As a** Cầu thủ sử dụng ứng dụng trên điện thoại,
- **I want** nhận được thông báo đẩy (Push Notification) ngay cả khi đã tắt ứng dụng, và bấm vào thông báo để mở đúng màn hình liên quan,
- **So that** tôi không bỏ lỡ yêu cầu nhận kèo (tự huỷ sau 2 giờ), nhắc điểm danh hay nhắc đóng quỹ.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Xin quyền & đăng ký FCM token):**
  - **Given** ứng dụng đã tích hợp cấu hình Firebase thật và người dùng vừa đăng nhập thành công,
  - **When** người dùng cấp quyền nhận thông báo trên hệ điều hành,
  - **Then** ứng dụng lấy `fcmToken` từ `firebase_messaging` và gọi `POST /v1/me/devices` (`{ fcmToken, platform: 'android' | 'ios' }`) để lưu vào bảng `devices`; khi token xoay vòng (`onTokenRefresh`), tự động cập nhật lại.
- **AC2 (Tôn trọng cài đặt thông báo ở Màn 23 & Điều hướng khi bấm thông báo):**
  - **Given** một sự kiện phát sinh thông báo (ví dụ có đội gửi yêu cầu nhận kèo `request.received`),
  - **When** worker chạy job `push.send`,
  - **Then** worker kiểm tra `notification_settings` của người nhận: chỉ gửi FCM nếu nhóm tương ứng (`matchUpdates`, `teamActivity`, `community`) đang bật (`true`); khi người dùng bấm vào thông báo trên thanh trạng thái điện thoại, ứng dụng mở thẳng tới màn hình đích dựa vào `payload` (`postId`, `requestId`, `matchId`, `teamId`).
- **AC3 (Kích hoạt nút "Nhắc người chưa trả lời" ở Màn 18 và "Nhắc đóng quỹ" ở Màn 6):**
  - **Given** Đội trưởng bấm `"Nhắc người chưa trả lời"` trên lịch điểm danh (Màn 18) hoặc Thủ quỹ bấm `"Nhắc đóng quỹ"` trên màn Quỹ (Màn 6),
  - **When** gọi API nhắc nhở,
  - **Then** hệ thống tạo thông báo trong app và đẩy FCM tới đúng danh sách thành viên chưa điểm danh / chưa đóng quỹ, thay thế thông báo tạm *"sẽ có ở bản sau"*.

---

### US-M6-05: Giám sát lỗi & Crash Reporting với Sentry (App + Backend)
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** **CÓ** (Tạo tài khoản Sentry & cấp `SENTRY_DSN`)

**User Story:**
- **As a** Kỹ sư vận hành (Teamlead / Dev),
- **I want** mọi lỗi không bắt được (unhandled exception / crash) trên cả ứng dụng Flutter và Backend NestJS đều tự động gửi báo cáo về Sentry kèm ngữ cảnh đã ẩn thông tin nhạy cảm,
- **So that** đội phát triển phát hiện và vá lỗi ngay khi người dùng gặp sự cố ngoài thực tế.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Bắt lỗi Backend 5xx & Worker BullMQ):**
  - **Given** `SENTRY_DSN` được cấu hình trong `.env` của backend và worker,
  - **When** xảy ra một lỗi hệ thống `500 Internal Server Error` hoặc một job BullMQ thất bại sau khi hết lượt thử lại (`attempts`),
  - **Then** lỗi được gửi lên Sentry kèm `requestId`, route, `userId` (nếu có), nhưng **tự động lọc bỏ** header `Authorization`, `refreshToken`, mật khẩu và token trong body.
- **AC2 (Bắt lỗi Crash / FlutterError trên App):**
  - **Given** ứng dụng chạy bản release có truyền `--dart-define=SENTRY_DSN=...`,
  - **When** xảy ra `FlutterError` hoặc lỗi bất đồng bộ trong `PlatformDispatcher.instance.onError`,
  - **Then** `sentry_flutter` ghi nhận stack trace, phiên bản app (`version+buildNumber`), loại máy và màn hình hiện tại (`go_router` route observer).
- **AC3 (An toàn khi chạy local không có DSN):**
  - **Given** môi trường dev không cấu hình `SENTRY_DSN`,
  - **When** khởi động backend và app,
  - **Then** ứng dụng vẫn chạy bình thường mà không báo lỗi khởi tạo Sentry.

---

### US-M6-06: Triển khai VPS Production, HTTPS Caddy, R2 & Sao lưu DB tự động
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Thuê VPS, mua tên miền, tài khoản Cloudflare R2)

**User Story:**
- **As a** Quản trị viên hệ thống,
- **I want** hệ thống chạy ổn định trên VPS với chứng chỉ HTTPS tự động (Caddy), kho ảnh S3 công khai (R2/SeaweedFS) và lịch sao lưu PostgreSQL tự động mỗi đêm giữ 7 bản,
- **So that** người dùng truy cập được mọi lúc và dữ liệu đội/quỹ/kèo được bảo vệ an toàn trước sự cố hỏng ổ cứng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Chạy Docker Compose & HTTPS trên VPS):**
  - **Given** tên miền `api.<tenmien>` đã trỏ về IP của VPS và `.env` production đã cấu hình,
  - **When** chạy `docker compose up -d` với `CADDY_SITE=api.<tenmien>`,
  - **Then** Caddy tự cấp chứng chỉ TLS Let's Encrypt, endpoint `GET https://api.<tenmien>/v1/health` trả về HTTP `200 OK`, kết nối WebSocket `/v1/socket` hoạt động qua `wss://`.
- **AC2 (Sao lưu tự động giữ 7 bản):**
  - **Given** dịch vụ chạy trên VPS,
  - **When** cron job / script `scripts/backup-db` chạy vào 03:00 sáng hàng ngày,
  - **Then** hệ thống xuất file nén `pg_dump` vào thư mục `backups/` (và đồng bộ lên bucket lưu trữ dự phòng nếu cấu hình), tự động xoá các bản sao lưu cũ hơn 7 ngày và kiểm tra khôi phục thử (`pg_restore`) thành công.

---

### US-M6-07: Nén ảnh phía client trước khi tải lên & gắn chọn ảnh vào UI Đăng kèo / Hồ sơ / Quỹ
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Người dùng tải ảnh lên ứng dụng (ảnh sân khi đăng kèo, ảnh đại diện cá nhân, ảnh hoá đơn khi chi quỹ),
- **I want** ứng dụng tự động nén và giảm kích thước ảnh ngay trên điện thoại trước khi tải lên kho S3,
- **So that** việc tải ảnh qua mạng 4G diễn ra nhanh chóng, không bị lỗi vượt dung lượng 10MB và hiển thị mượt trên Bảng tin.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Nén ảnh tự động trên máy):**
  - **Given** người dùng chọn một bức ảnh gốc từ thư viện hoặc chụp bằng camera (ví dụ ảnh 8MB, độ phân giải 4000×3000),
  - **When** ứng dụng chuẩn bị tải ảnh lên,
  - **Then** bộ xử lý ảnh phía client tự động thu phóng cạnh dài nhất về tối đa `1600px` (hoặc `512px` đối với avatar) và nén JPEG/WebP chất lượng ~80% sao cho dung lượng sau nén thông thường `< 1MB`, rồi mới gọi `POST /v1/media/uploads` và `PUT` lên S3.
- **AC2 (Gắn chọn ảnh vào Màn 2 Đăng kèo, Màn 20 Thêm khoản chi, Màn 23 Hồ sơ):**
  - **Given** người dùng đang ở Màn 2 (Đăng kèo), Màn 20 (tab Chi quỹ - mục *"Ảnh hoá đơn / Thêm ảnh"*) hoặc Màn 23 (Sửa hồ sơ cầu thủ),
  - **When** bấm thêm ảnh và lưu biểu mẫu,
  - **Then** ảnh hiển thị xem trước (preview) có nút xoá chọn lại, tiến trình tải lên có chỉ báo loading, và `mediaKeys` / `avatarUrl` / `receiptUrl` được gửi kèm API tương ứng.

---

### US-M6-08: Đóng gói bản phát hành (Android/iOS) & Chuẩn bị Store Listing
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Tài khoản Google Play Console, Apple App Store Connect, máy Mac/Codemagic)

**User Story:**
- **As a** Cầu thủ muốn sử dụng Sân 7,
- **I want** tìm thấy ứng dụng Sân 7 trên Google Play và Apple App Store với ảnh chụp màn hình rõ ràng, mô tả tiếng Việt đầy đủ và cài đặt chỉ bằng một chạm,
- **So that** tôi và đồng đội tải được ứng dụng chính thức mà không cần cài file APK thủ công.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Bộ tài sản Store Listing tiếng Việt):**
  - **Given** chuẩn bị gửi duyệt lên hai kho ứng dụng,
  - **When** hoàn tất hồ sơ Store Listing trong `docs/store/`,
  - **Then** có đầy đủ: Tên ứng dụng (*"Sân 7 – Cáp kèo, Đặt sân & Quản lý đội"*), mô tả ngắn (80 ký tự), mô tả chi tiết (≤ 4.000 ký tự), bộ từ khoá, App Icon 1024×1024px không nền trong suốt, Feature Graphic 1024×500px (Google Play), bộ 6 ảnh chụp màn hình (Bảng tin, Đăng kèo, Bản đồ đặt sân, Đội bóng & Quỹ, Kết quả trận, Chat hai đội), bảng khai báo Data Safety / App Privacy và tài khoản demo cho người duyệt bài của Apple/Google.
- **AC2 (Đóng gói bản ký số Release):**
  - **Given** mã nguồn trên nhánh phát hành đã vượt qua `flutter analyze`, `flutter test` và `npm test`,
  - **When** chạy lệnh đóng gói sản phẩm với biến môi trường production,
  - **Then** tạo thành công file Android App Bundle (`.aab`) được ký bằng upload keystore riêng (không dùng debug key) và gói iOS (`.ipa`) đẩy lên TestFlight / Play Console Internal Testing.

---

### US-M6-09: Bổ sung API liệt kê lịch đăng kèo & hoàn thiện UI hẹn lịch (Màn 2, 10, 18)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Đội trưởng hoặc Đội phó,
- **I want** chọn chế độ "Hẹn lịch" ngay trên màn Đăng kèo mới (Màn 2) và xem/tạm dừng/sửa/xoá các lịch đăng định kỳ trong tab "Lịch đăng" của Màn 10 và mục Sắp tới của Màn 18,
- **So that** tôi quản lý trọn vẹn các lịch tự động đăng kèo hàng tuần trên giao diện ứng dụng mà không bị đứt luồng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (API lấy danh sách lịch đăng):**
  - **Given** đội của người dùng đã tạo các lịch hẹn đăng kèo,
  - **When** gọi `GET /v1/me/post-schedules` (hoặc `GET /v1/teams/:teamId/post-schedules`),
  - **Then** backend trả về danh sách các lịch hẹn đang hoạt động (`scheduled`) kèm thông tin kèo mẫu, giờ đăng kế tiếp và cờ `repeatWeekly`.
- **AC2 (Khối "Thời điểm đăng" trên Màn 2 và thẻ lịch lặp trên Màn 10, 18):**
  - **Given** người dùng đang ở Màn 2 (Đăng kèo mới),
  - **When** chuyển công tắc `"Thời điểm đăng"` từ `"Đăng ngay"` sang `"Hẹn lịch"`, chọn giờ đăng và bật/tắt `"Lặp hàng tuần"`,
  - **Then** nút chính đổi thành `"Hẹn lịch đăng"`, gọi `POST /v1/teams/:teamId/post-schedules` và hiển thị lịch vừa tạo trong tab `"Lịch đăng"` của Màn 10 (cho phép Sửa / Huỷ lịch) cũng như nhãn `"Kèo đang tự đăng theo lịch"` ở Màn 18.

---

### US-M6-10: Nối nút "Nhắn tin" từ Màn 9, 13, 22 sang màn Chat (Màn 21) & nút "Hoàn tác"
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Đội trưởng đang xem yêu cầu nhận kèo (Màn 9), vừa gửi nhận kèo (Màn 13) hoặc xem hồ sơ đội đối thủ (Màn 22),
- **I want** bấm nút "Nhắn tin" để mở ngay cuộc trò chuyện với đội đó và có thể bấm "Hoàn tác" trong vài giây nếu lỡ tay bấm nhầm Chấp nhận/Từ chối ở Màn 9,
- **So that** luồng thương lượng giữa hai đội liền mạch đúng như bản vẽ thiết kế.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Nối nút Nhắn tin):**
  - **Given** hai đội đã có trận đấu chung (`matchId`) hoặc kèo đã chốt,
  - **When** người dùng bấm nút `"Nhắn tin"` trên Màn 9 (`request_detail_screen.dart`), Màn 13 (`send_request_screen.dart`) hoặc Màn 22 (`team_profile_screen.dart`),
  - **Then** ứng dụng mở thẳng Màn 21 (`ChatScreen`) của trận đấu đó (thay vì báo *"Nhắn tin giữa các đội có ở bản sau"*).
- **AC2 (Hoàn tác thao tác trên Màn 9):**
  - **Given** chủ kèo vừa bấm `"Từ chối"` một yêu cầu nhận kèo trên Màn 9,
  - **When** thanh thông báo kèm nút `"Hoàn tác"` hiện lên trong 5 giây và người dùng bấm `"Hoàn tác"`,
  - **Then** yêu cầu được khôi phục về trạng thái chờ (`pending`) trước khi thông báo từ chối gửi đi.

---

### US-M6-11: Đóng các mục lệch mức Vừa luồng Bảng tin & Cáp kèo (Màn 1, 2, 11, 14)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Cầu thủ tìm kèo trên Bảng tin,
- **I want** tìm kiếm kèo theo từ khoá, thấy đúng nút "Ứng tuyển" trên thẻ tuyển người, xem thẻ kết quả trận trên Bảng tin và lọc/so sánh các đội nhận kèo theo khoảng cách địa lý (Màn 11),
- **So that** giao diện khớp hoàn toàn với bản vẽ thiết kế và giúp tôi chọn đối thủ gần sân nhất.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Màn 1 - Bảng tin):** Có nút Tìm kiếm trên thanh tiêu đề đầu trang; thẻ loại `"Tuyển người"` (`recruit`) hiển thị nút `"Ứng tuyển"` kèm các chip vị trí cần tuyển (`Thủ môn`, `Hậu vệ`, `Tiền vệ`, `Tiền đạo`); hiển thị thẻ bài kết quả trận đấu (`3–2`, người ghi bàn, MVP).
- **AC2 (Màn 11 - So sánh đội nhận kèo):** Bổ sung hàng `"Khoảng cách"` (tính theo km từ khu vực/sân) và đủ bộ 3 chip lọc `"Uy tín cao"` / `"Gần nhất"` / `"Đăng ký sớm"`.
- **AC3 (Màn 14 - Chi tiết kèo):** Hiển thị thẻ sân kèm nút `"Chỉ đường"` và dòng tổng hợp số đội đã gửi nhận kèo (`"N đội đã gửi nhận kèo"`).

---

### US-M6-12: Đóng các mục lệch mức Vừa luồng Đặt sân, Kết quả & Đội bóng (Màn 3, 4, 6, 12, 16, 17, 19, 22)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Chốt mô tả quyền Phó đội Màn 19, cấp dữ liệu sân thật & key Map tile)

**User Story:**
- **As a** Thành viên đội bóng,
- **I want** lọc bản đồ sân theo ngày và loại sân, xem đủ tiện ích/ảnh sân, chia sẻ vé đặt sân, gắn chip nhận xét đối thủ sau trận (Màn 17, 22), xem tiến độ đóng quỹ kèm avatar và quét mã QR mời vào đội (Màn 12),
- **So that** mọi thao tác đặt sân, quản lý quỹ và đánh giá đối thủ khớp với bản vẽ.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Màn 3, 4, 16 - Đặt sân):** Màn 3 có thêm chip lọc ngày (`Hôm nay`...) và `"Sân 7"`, đổi sang nguồn map tile production; Màn 4 hiển thị số lượng ảnh, điểm đánh giá, chip tiện ích (`cỏ mới`, `đèn LED`, `gửi xe`, `nước`, `phòng thay đồ`) và khoảng cách; Màn 16 có nút `"Chia sẻ"` vé đặt sân.
- **AC2 (Màn 17, 22 - Nhận xét sau trận & Hồ sơ đội):** Màn 17 hiển thị nhóm 5 chip nhận xét nhanh (`Đúng giờ`, `Đá đẹp`, `Vui vẻ`, `Trả tiền sòng phẳng`, `Đủ người`) gửi vào mảng `tags` của `PUT /v1/teams/:teamId/matches/:matchId/review`; Màn 22 hiển thị dòng tổng kết `"N trận · xT yH zB"` và số đếm từng thẻ nhận xét (`Đúng giờ 31`, `Đá đẹp 24`...).
- **AC3 (Màn 6, 12, 19 - Đội bóng & Quỹ):** Màn 6 hiển thị chữ thanh tiến độ `"12/18 đã đóng"` kèm cụm avatar người chưa đóng (`+N chưa đóng`); Màn 12 tích hợp thư viện quét camera cho nút `"Quét QR"` mã mời đội; Màn 19 cập nhật dòng mô tả quyền Phó đội theo quyết định của PO/anh Duy.

---

### US-M6-13: Rà soát vùng bấm 44×44px, tương phản AA & trạng thái mất mạng/loading toàn app
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** **CÓ** (Chốt kiểu hiển thị Toast)

**User Story:**
- **As a** Người dùng sử dụng ứng dụng ngoài sân bóng (ánh sáng mạnh, mạng 4G chập chờn),
- **I want** mọi nút bấm đều đủ lớn (tối thiểu 44×44px), độ tương phản chữ đạt chuẩn WCAG AA và ứng dụng thông báo rõ khi mất mạng hoặc đang xử lý,
- **So that** tôi không bấm nhầm và luôn biết trạng thái của ứng dụng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Vùng bấm & Tương phản):** Rà soát toàn bộ 24 màn mobile đảm bảo mọi `IconButton`, `TextButton`, `Pill`, chip lọc đều có vùng chạm `>= 44×44px`; không còn màu hard-code ngoài `tokens.dart`; tỷ lệ tương phản chữ/nền đạt tối thiểu `4.5:1`.
- **AC2 (Trạng thái Mất mạng & Loading đồng nhất):** Mọi màn hình khi mất kết nối mạng đều hiển thị thông báo tiếng Việt thân thiện kèm nút `"Thử lại"`; mọi nút gửi biểu mẫu đều khoá (`disabled`) và hiện vòng xoay khi đang chờ API.

---

### US-M6-14: Dịch vụ thêm tại sân & tạm tính chia tiền trên màn Đặt sân (Màn 15, 16)
- **Phân loại MoSCoW:** `Could Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Người đặt sân (Màn 15),
- **I want** chọn thêm các dịch vụ tại sân (nước suối, thuê áo bib) và xem bảng tạm tính số tiền chia với đội đối thủ theo tỷ lệ kèo,
- **So that** tôi biết chính xác tổng số tiền cần thanh toán tại sân cho cả hai đội.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1:** Trên Màn 15, người dùng tích chọn được các dịch vụ đi kèm (nếu sân có cung cấp), hệ thống cộng vào tổng tạm tính và hiển thị khối *"Chia tiền với đội đối theo kèo"* kèm phần tiền tương ứng của mỗi đội trên Màn 15 và Màn 16.

---

### US-M6-15: Cổng thanh toán đặt cọc sân online & Bản giao diện Desktop/Web (Màn 15, D)
- **Phân loại MoSCoW:** `Won't Have (Dời sang sau M6 theo PLAN.md mục 11)` | **Ước lượng:** `13 SP` | **Cần anh Duy:** **CÓ** (Ký hợp đồng cổng thanh toán & xác nhận chủ trương bản Desktop)

**Ghi chú PO:** Theo `docs/PLAN.md` mục 2 và mục 11, thanh toán đặt cọc online qua cổng đối tác và mở rộng ngoài mobile thuộc giai đoạn **Sau M6 (Tăng trưởng)**. Giữ bản trả tại sân (`deposit = 0`) cho đợt ra mắt M6 để rút ngắn thời gian lên Store và tiết kiệm chi phí pháp lý/cổng thanh toán.
