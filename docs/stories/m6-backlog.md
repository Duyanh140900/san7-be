# Product Backlog Chặng M6: Phát hành, Bảo mật & Hoàn thiện giao diện (Sân 7)

- **Phiên bản:** 1.2 | **Ngày cập nhật:** 17/11/2026
- **Người viết:** BA (kiêm PO)
- **Nguồn đối chiếu:** `docs/PLAN.md` (mục 11, 13, 16), `docs/HANDOVER.md` (mục 2), `docs/design/gap-report.md` (các mục mức Vừa M0–M4), `docs/reviews/m5-review.md` & `docs/reviews/m5-security-review.md`, các quyết định PM chốt cuối M5 (commit `3abba24`, `e25e0b9` và nhánh `seed-du-lieu`)
- **Phương pháp ưu tiên:** MoSCoW (`Must Have`, `Should Have`, `Could Have`, `Won't Have in M6`) + Thứ tự thực thi R1–R17
- **Đơn vị ước lượng:** Story Points (SP, thang Fibonacci 1–2–3–5–8–13) & Thời gian dự kiến (người-ngày / man-day)

---

## 1. Bảng tổng hợp Backlog M6 theo Thứ tự ưu tiên thực thi & Cờ phụ thuộc anh Duy

| Thứ tự | Mã Story | Tên User Story | Nhóm | MoSCoW | Ước lượng | Cần anh Duy (Tài khoản / Tiền / Quyết định) |
|:---:|---|---|---|---|---|---|
| **1** | **US-M6-01** | Xoá tài khoản người dùng trong app (Account Deletion) | Pháp lý & Store | **Must Have** | 3 SP (~1 ngày) | Không |
| **2** | **US-M6-04** | Hoàn thiện Push Notification FCM & Thực thi lọc theo Cài đặt thông báo Màn 23 | Vận hành & Kỹ thuật | **Must Have** | 3 SP (~1 ngày) | **CÓ:** Tạo Firebase project (miễn phí), cấp `google-services.json`, `GoogleService-Info.plist`, APNs key & `FIREBASE_SERVICE_ACCOUNT` |
| **3** | **US-M6-07** | Nén ảnh & chuyển định dạng sang JPEG/WebP phía client (bỏ HEIC) + Đổi Avatar (`PATCH /v1/me`) | Hoàn thiện M5 & Hiệu năng | **Must Have** | 3 SP (~1 ngày) | Không |
| **4** | **US-M6-17** | Gắn ảnh biên lai (`receipt`) vào giao dịch Chi quỹ (Màn 20) & Xem biên lai nội bộ đội (`GET /v1/media/receipts/:id`, Màn 6) | Hoàn thiện M5 / Màn 6, 20 | **Must Have** | 3 SP (~1 ngày) | Không |
| **5** | **US-M6-11** | Gia cố bảo mật & độ tin cậy Backend từ `m5-review.md` (Socket.IO CORS/Rate limit, FK Chat, huỷ lịch khi hạ quyền, E2E Guard thật) | Bảo mật & Kỹ thuật (`m5-review.md`) | **Must Have** | 5 SP (~1,5 ngày) | Không |
| **6** | **US-M6-05** | Giám sát lỗi & Crash Reporting với Sentry (App + Backend) | Vận hành & Kỹ thuật | **Must Have** | 3 SP (~1 ngày) | **CÓ:** Tạo project Sentry (gói Free/Developer) & cấp `SENTRY_DSN` |
| **7** | **US-M6-02** | Đăng nhập bằng Apple (Sign in with Apple) | Pháp lý & Store | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Tài khoản Apple Developer ($99 / ~2,5 triệu đ/năm) + cấu hình Apple Service ID / Key |
| **8** | **US-M6-03** | Chính sách quyền riêng tư & Điều khoản sử dụng công khai | Pháp lý & Store | **Must Have** | 2 SP (~0,5 ngày) | **CÓ:** Duyệt nội dung pháp lý, thông tin chủ thể liên hệ & tên miền đăng tải |
| **9** | **US-M6-06** | Triển khai VPS Production, HTTPS Caddy, R2, Hardening Container & Sao lưu DB tự động | Hạ tầng & Vận hành | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Thuê VPS (~1–5 triệu đ/tháng), mua tên miền (~0,3–1 triệu đ/năm), tài khoản Cloudflare R2 |
| **10** | **US-M6-08** | Đóng gói bản phát hành (Android/iOS) & Chuẩn bị Store Listing | Phát hành Store | **Must Have** | 5 SP (~1,5 ngày) | **CÓ:** Google Play Console ($25 / ~650k đ một lần), Apple App Store Connect (~2,5 triệu đ/năm), máy Mac hoặc Codemagic để ký iOS |
| **11** | **US-M6-09** | **[Đã xong cốt lõi ở M5 — Thu nhỏ]** Bổ sung Sửa/Tạm dừng lịch đăng (Màn 10) & Nhãn lịch tự đăng (Màn 18) | Bù nợ M5 / Màn 10, 18 | **Should Have** | 2 SP (~0,5 ngày) | Không (`GET post-schedules` chỉ `captain`/`vice`, lọc bỏ lịch đã huỷ & UI Hẹn lịch Màn 2/10 đã xong ở M5) |
| **12** | **US-M6-10** | Hoàn thiện Chat Màn 21 (\"Chốt kèo\", \"Đã xem\", header đội trưởng) & Nối nút \"Nhắn tin\" từ Màn 9, 13, 22 + nút \"Hoàn tác\" | Bù nợ M5 / Màn 21 | **Should Have** | 5 SP (~1,5 ngày) | Không |
| **13** | **US-M6-12** | Đóng các mục lệch mức Vừa luồng Đặt sân (kèm bộ seed 184 sân thật OpenStreetMap & ghi công ODbL), Kết quả & Đội bóng (Màn 3, 4, 6, 12, 16, 17, 19, 20, 22) | Gap Report M0–M4 (Vừa) & Dữ liệu sân | **Should Have** | 5 SP (~1,5 ngày) | **CÓ:** Bổ sung **bảng giá thật, khung giờ hoạt động và SĐT chủ sân** cho 184 sân OSM đã seed trên nhánh `seed-du-lieu` |
| **14** | **US-M6-13** | Đóng các mục lệch mức Vừa luồng Bảng tin & Cáp kèo (Màn 1, 2, 11, 14) | Gap Report M0–M4 (Vừa) | **Should Have** | 5 SP (~1,5 ngày) | Không |
| **15** | **US-M6-14** | Rà soát vùng bấm 44×44px, tương phản AA, trạng thái mất mạng/loading & sửa đơ khung hình khi lưu hồ sơ | Gap xuyên suốt (Vừa) | **Should Have** | 3 SP (~1 ngày) | **CÓ:** Chốt kiểu hiển thị Toast chuẩn trên toàn app |
| **16** | **US-M6-15** | Dịch vụ thêm tại sân & tạm tính chia tiền trên màn Đặt sân (Màn 15, 16) | Gap Report M3 (Vừa) | **Could Have** | 3 SP (~1 ngày) | Không (chưa gồm cổng thanh toán cọc online) |
| **17** | **US-M6-16** | Cổng thanh toán đặt cọc sân online & Bản giao diện Desktop/Web (Màn 15, D) | Sau M6 (Post-launch) | **Won't Have (M6)** | 13 SP (~4 ngày) | **CÓ:** Ký hợp đồng cổng thanh toán (PayOS/VNPay/SePay) & xác nhận khi nào mở bản Desktop |

---

## 2. Top 5 User Story M6 nên làm trước (Không phụ thuộc chờ tài khoản trả phí bên ngoài)

Để đội phát triển bắt tay làm được ngay lập tức trong khi chờ anh Duy đăng ký Apple Developer / VPS, **Top 5 story ưu tiên cao nhất đầu M6** là:

1. **US-M6-01 — Xoá tài khoản người dùng (Must Have, 3 SP):** Yêu cầu bắt buộc của cả Apple App Store (Guideline 5.1.1(v)) và Google Play đối với mọi ứng dụng có tạo tài khoản. Không phụ thuộc bên thứ ba, Backend + Frontend làm được ngay.
2. **US-M6-04 — Thực thi lọc Cài đặt thông báo ở Backend & Hoàn thiện Push FCM (Must Have, 3 SP):** Vá phát hiện mức Vừa `V6` trong review bảo mật (hiện 3 công tắc ở Màn 23 đã lưu DB nhưng pipeline `NotificationWriter`/`PushService` chưa lọc theo cờ khi gửi) và kích hoạt FCM trên máy thật.
3. **US-M6-07 — Nén ảnh & chuyển định dạng sang JPEG/WebP phía client (bỏ HEIC) + Đổi Avatar Màn 23 (Must Have, 3 SP):** Do backend đã bỏ hỗ trợ `image/heic` (chỉ nhận `image/jpeg`, `image/png`, `image/webp`), phía client Flutter cần tự động chuyển đổi định dạng sang `jpeg`/`webp` và nén ảnh trước khi upload, đồng thời nối UI đổi Avatar qua `PATCH /v1/me` (`avatarKey`).
4. **US-M6-17 — Gắn ảnh biên lai (`receipt`) vào giao dịch Chi quỹ ở Màn 20 & Xem biên lai nội bộ đội qua `GET /v1/media/receipts/:id` (Must Have, 3 SP):** Khép kín luồng biên lai quỹ bảo mật (backend đã có `POST /v1/media/uploads` với `purpose = receipt` + `teamId`, `POST /v1/media/uploads/finalize` và `GET /v1/media/receipts/:id` chỉ cho thành viên đội xem; cần nối vào giao dịch chi quỹ ở Màn 20 và hiển thị ở Màn 6).
5. **US-M6-11 — Gia cố bảo mật & độ tin cậy Backend từ `m5-review.md` (Must Have, 5 SP):** Giải quyết toàn bộ các mục *"Nên sửa"* và *"Gợi ý"* còn lại mà Teamlead đã chỉ ra (allowlist CORS + rate limit cho Socket.IO join, thêm FK/index cho `match_messages`, join room `post:{postId}`, fail-fast biến môi trường S3 HTTPS, và chạy e2e test với Guard thật).

---

## 3. Tổng hợp các việc cần anh Duy thực hiện (Tài khoản, Chi phí & Quyết định)

### A. Tài khoản & Chi phí (Cần thanh toán / đăng ký cho đợt lên Store M6)
1. **Google Play Console:** Đăng ký tài khoản nhà phát triển Android — phí một lần **$25 (~650.000đ)**, xác minh danh tính để tạo ứng dụng `vn.san7.app`.
2. **Apple Developer Program:** Đăng ký tài khoản nhà phát triển iOS — phí **$99/năm (~2.500.000đ/năm)** để mở quyền *Sign in with Apple*, tạo APNs Push Key và đưa app lên TestFlight / App Store.
3. **Hạ tầng máy chủ (VPS + Tên miền + Lưu trữ ảnh):**
   - Thuê **VPS** (Contabo hoặc tương đương, 8GB–16GB RAM) — khoảng **1.000.000đ – 5.000.000đ/tháng** (theo `PLAN.md` mục 16).
   - Mua **Tên miền** (ví dụ `san7.vn` hoặc tương đương) — khoảng **300.000đ – 1.000.000đ/năm**, trỏ DNS `api.<tenmien>` về VPS.
   - Tạo bucket **Cloudflare R2** (hoặc dùng SeaweedFS nội bộ sau proxy API `/v1/media/public/:id` và `/v1/media/receipts/:id`) và cấp `S3_ENDPOINT`, `S3_PUBLIC_URL`, `MEDIA_PUBLIC_URL`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`.
4. **Máy build iOS (Mac / Codemagic):** Chuẩn bị máy Mac hoặc tài khoản CI/CD **Codemagic** để build và ký file `.ipa` đẩy lên App Store Connect.

### B. Khoá cấu hình dịch vụ miễn phí (Cần tạo trên tài khoản của anh Duy)
1. **Firebase Console:** Tạo project Firebase cho `vn.san7.app`, tải `google-services.json` (Android), `GoogleService-Info.plist` (iOS), gắn APNs key và xuất `FIREBASE_SERVICE_ACCOUNT` (base64 JSON) cho Backend.
2. **Sentry.io:** Tạo project NestJS và Flutter trên Sentry (gói miễn phí), gửi `SENTRY_DSN` cho đội kỹ thuật.

### C. Quyết định đã chốt (PM & PO) và dữ liệu cần anh Duy cấp
- **Đã chốt (không cần hỏi lại):**
  1. **Bản Desktop (Màn D) & Cọc online qua cổng thanh toán (Màn 15):** Để **Sau M6** (xem `US-M6-16`).
  2. **Bản đồ (Màn 3) & Nguồn sân OpenStreetMap:** Giữ nền **OpenStreetMap** và sử dụng bộ seed **184 sân thật** từ OpenStreetMap (giấy phép ODbL, hiển thị ghi công `"© OpenStreetMap contributors"` trong app) trên nhánh `seed-du-lieu`.
  3. **Quyền Phó đội (`vice`) & Lịch đăng (`GET /v1/teams/:teamId/post-schedules`):** Chỉ `captain` và `vice` được tạo/xem/huỷ lịch đăng kèo, API `GET post-schedules` không trả về lịch đã huỷ (`status = 'scheduled'`); khi tác giả mất quyền trong đội thì tự động huỷ lịch đăng.
  4. **Định dạng ảnh tải lên & Quyền xem biên lai quỹ:** Bỏ hỗ trợ `image/heic` trên backend (client tự chuyển sang `jpeg`/`webp` trước khi upload); ảnh biên lai chi quỹ (`purpose = receipt`) gắn với `teamId` và chỉ thành viên trong đội mới đọc được qua `GET /v1/media/receipts/:id`.
- **Cần anh Duy cung cấp trong M6:**
  1. **Bảng giá thật, khung giờ hoạt động và SĐT chủ sân** cho các sân bóng trong bộ seed 184 sân thật từ OpenStreetMap (hiện OSM đã có tên sân, toạ độ, quận/huyện tại Hà Nội & TP.HCM nhưng còn thiếu giá thật — đang gắn tạm `price_estimated = true`, thiếu khung giờ mở cửa và SĐT liên hệ).
  2. **Thông tin chủ thể pháp lý & email liên hệ** để điền vào trang Chính sách quyền riêng tư & Điều khoản sử dụng (`US-M6-03`).

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
- **AC3 (Thực thi xoá tài khoản, huỷ lịch đăng & thu hồi phiên):**
  - **Given** người dùng không bị vướng điều kiện Đội trưởng (hoặc đội chỉ có 1 mình người dùng),
  - **When** xác nhận `"Xoá vĩnh viễn"` (`DELETE /v1/me`),
  - **Then** trong một transaction: thu hồi toàn bộ refresh token, ngắt mọi kết nối Socket.IO của user, huỷ các `post_schedules` đang `scheduled` của user, xoá `devices`, `notification_settings`, ẩn danh hoặc xoá bản ghi `users` (giữ toàn vẹn lịch sử trận đấu/quỹ chung của các đội cũ), xoá ảnh thuộc `ownerId = userId` trên S3, xoá token dưới máy và đưa người dùng về Màn 12 (Đăng nhập).

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
  - **Then** trang hiển thị đầy đủ nội dung tiếng Việt nêu rõ: dữ liệu thu thập (email, tên, vị trí tìm sân, ảnh tải lên), mục đích sử dụng, không bán dữ liệu cho bên thứ ba, cách yêu cầu xoá tài khoản, ghi công dữ liệu bản đồ/sân bóng `"© OpenStreetMap contributors"` (ODbL) và thông tin liên hệ.
- **AC2 (Mở từ Màn 12 và Màn 23 trong app):**
  - **Given** người dùng đang ở Màn 12 (dòng *"Bằng việc tiếp tục, bạn đồng ý với Điều khoản và Chính sách quyền riêng tư"*) hoặc ở Màn 23 (Cá nhân & cài đặt),
  - **When** bấm vào liên kết `"Điều khoản"` hoặc `"Chính sách quyền riêng tư"`,
  - **Then** ứng dụng mở nội dung tương ứng (in-app browser hoặc màn đọc tĩnh) mà không bị lỗi đường dẫn chết.

---

### US-M6-04: Hoàn thiện Push Notification FCM & Thực thi lọc theo Cài đặt thông báo Màn 23
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** **CÓ** (Tạo Firebase project, cấp `google-services.json`, `GoogleService-Info.plist`, APNs key & `FIREBASE_SERVICE_ACCOUNT`)

**User Story:**
- **As a** Cầu thủ sử dụng ứng dụng trên điện thoại,
- **I want** nhận được thông báo đẩy (Push Notification) ngay cả khi đã tắt ứng dụng theo đúng các mục tôi đã bật tại Màn 23, và bấm vào thông báo để mở đúng màn hình liên quan,
- **So that** tôi không bỏ lỡ yêu cầu nhận kèo (tự huỷ sau 2 giờ), nhắc điểm danh hay nhắc đóng quỹ, đồng thời không bị làm phiền bởi nhóm thông báo tôi đã tắt.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Xin quyền & đăng ký FCM token):**
  - **Given** ứng dụng đã tích hợp cấu hình Firebase thật và người dùng vừa đăng nhập thành công,
  - **When** người dùng cấp quyền nhận thông báo trên hệ điều hành,
  - **Then** ứng dụng lấy `fcmToken` từ `firebase_messaging` và gọi `POST /v1/me/devices` (`{ fcmToken, platform: 'android' | 'ios' }`) để lưu vào bảng `devices`; khi token xoay vòng (`onTokenRefresh`), tự động cập nhật lại.
- **AC2 (Thực thi lọc theo `notification_settings` ở Màn 23 - Vá mục V6 trong Security Review):**
  - **Given** người dùng đã tắt một trong 3 cờ `matchUpdates`, `teamActivity`, hoặc `community` trên Màn 23,
  - **When** một sự kiện phát sinh thông báo thuộc nhóm đó,
  - **Then** `NotificationWriter` / `PushService` kiểm tra `notification_settings` của người nhận và **không gửi push FCM** nếu nhóm tương ứng đang `false`; khi thông báo được phép gửi và người dùng bấm vào trên thanh trạng thái điện thoại, ứng dụng mở thẳng tới màn hình đích dựa vào `payload` (`postId`, `requestId`, `matchId`, `teamId`).
- **AC3 (Kích hoạt nút \"Nhắc người chưa trả lời\" ở Màn 18 và \"Nhắc đóng quỹ\" ở Màn 6):**
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

### US-M6-06: Triển khai VPS Production, HTTPS Caddy, R2, Hardening Container & Sao lưu DB tự động
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Thuê VPS, mua tên miền, tài khoản Cloudflare R2)

**User Story:**
- **As a** Quản trị viên hệ thống (Teamlead / DevOps),
- **I want** hệ thống chạy ổn định trên VPS với chứng chỉ HTTPS tự động (Caddy), kho ảnh S3 an toàn, container đã được khoá quyền tối thiểu (hardened) và lịch sao lưu PostgreSQL tự động mỗi đêm giữ 7 bản,
- **So that** người dùng truy cập được mọi lúc và dữ liệu đội/quỹ/kèo được bảo vệ an toàn trước sự cố hỏng ổ cứng hay tấn công hạ tầng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Chạy Docker Compose, HTTPS & Fail-fast cấu hình S3 ở Production):**
  - **Given** tên miền `api.<tenmien>` đã trỏ về IP của VPS và `.env` production đã cấu hình,
  - **When** khởi động stack ở `NODE_ENV=production`,
  - **Then** `env.ts` kiểm tra fail-fast bắt buộc đủ biến `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY` và bắt buộc `S3_PUBLIC_URL` / `MEDIA_PUBLIC_URL` dùng giao thức `https://` (theo mục *"Nên sửa #4"* trong `m5-review.md`); Caddy tự cấp chứng chỉ TLS Let's Encrypt, `GET https://api.<tenmien>/v1/health` trả về `200 OK`, WebSocket `/v1/socket` hoạt động qua `wss://`.
- **AC2 (Hardening Container theo mục \"Gợi ý\" trong `m5-review.md`):**
  - **Given** file `docker-compose.yml` cho môi trường production,
  - **When** kiểm tra cấu hình các image (`seaweedfs`, `cloudflared`, `api`, `worker`),
  - **Then** toàn bộ image được pin version/digest cụ thể (không dùng tag `:latest`), chạy với non-root user, bật `security_opt: ["no-new-privileges:true"]`, `cap_drop: ["ALL"]` và giới hạn `mem_limit` / `cpus`.
- **AC3 (Sao lưu tự động giữ 7 bản):**
  - **Given** dịch vụ chạy trên VPS,
  - **When** cron job / script `scripts/backup-db` chạy vào 03:00 sáng hàng ngày,
  - **Then** hệ thống xuất file nén `pg_dump` vào thư mục `backups/` (và đồng bộ lên bucket dự phòng), tự động xoá các bản sao lưu cũ hơn 7 ngày và kiểm tra khôi phục thử (`pg_restore`) thành công.

---

### US-M6-07: Nén ảnh & chuyển định dạng sang JPEG/WebP phía client (bỏ HEIC) + Đổi Avatar (`PATCH /v1/me`, Màn 23)
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không
- **Ghi chú cập nhật từ M5:** Backend (commit `3abba24`) đã nâng `sharp` lên `^0.35.5`, bỏ `image/heic` khỏi whitelist (chỉ cho phép `image/jpeg`, `image/png`, `image/webp`) và hỗ trợ `avatarKey` trong `PATCH /v1/me` kèm giữ nguyên avatar tự upload khi đăng nhập lại Google (`aaf429a`).

**User Story:**
- **As a** Người dùng tải ảnh lên ứng dụng (ảnh đại diện ở Màn 23, ảnh sân khi đăng kèo ở Màn 2, ảnh biên lai ở Màn 20),
- **I want** ứng dụng trên điện thoại tự động chuyển đổi mọi ảnh chụp/chọn từ máy (kể cả ảnh HEIC/HEIF mặc định của iPhone) sang định dạng `image/jpeg` hoặc `image/webp` và nén giảm dung lượng trước khi tải lên, đồng thời cho phép tôi đổi ảnh đại diện ở Màn 23,
- **So that** tôi không bao giờ gặp lỗi `415 media_type_not_allowed` khi chọn ảnh từ iOS/Android, tải ảnh nhanh qua 4G và tốn ít quota 50MB/ngày.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Chuyển định dạng sang JPEG/WebP & nén ảnh phía client trước khi gọi `POST /v1/media/uploads`):**
  - **Given** người dùng chọn một bức ảnh từ thư viện hoặc chụp bằng camera trên iOS/Android (bao gồm ảnh định dạng `.heic`/`.heif` hoặc ảnh gốc dung lượng lớn > 5MB, độ phân giải 4000×3000),
  - **When** ứng dụng chuẩn bị tải ảnh lên,
  - **Then** client bắt buộc chuyển đổi định dạng sang `image/jpeg` hoặc `image/webp`, thu phóng cạnh dài nhất về tối đa `1600px` (`512px` với avatar) và nén chất lượng ~80% (dung lượng sau nén thông thường `< 1MB`), sau đó mới gọi `POST /v1/media/uploads` với `contentType` thuộc `image/jpeg` hoặc `image/webp` (tuyệt đối không gửi `image/heic`).
- **AC2 (Luồng đổi Avatar trên Màn 23 qua `avatarKey` của `PATCH /v1/me`):**
  - **Given** người dùng đang ở Màn 23 (Sửa hồ sơ cầu thủ),
  - **When** bấm vào ảnh đại diện, chọn ảnh mới, ứng dụng chuyển sang JPEG/WebP + nén, gọi `POST /v1/media/uploads` (`purpose = avatar`), `PUT` bytes lên URL có chữ ký và gửi `avatarKey` vào `PATCH /v1/me`,
  - **Then** backend tự động xác minh + re-encode WebP (`useAvatar`), cập nhật `users.avatarUrl` trỏ về `/v1/media/public/:id` và hiển thị ngay ảnh đại diện mới trên Màn 23, Bảng tin và khung Chat.
- **AC3 (Thông báo lỗi tiếng Việt rõ ràng nếu ảnh không đọc được trên máy):**
  - **Given** người dùng chọn một tệp bị hỏng hoặc định dạng không phải ảnh mà bộ giải mã của máy không chuyển sang JPEG/WebP được,
  - **When** bước xử lý phía client thất bại,
  - **Then** ứng dụng chặn ngay tại máy và hiển thị thông báo tiếng Việt: `"Không thể xử lý ảnh này. Vui lòng chọn ảnh JPEG, PNG hoặc WebP khác."` mà không tạo bản ghi upload thừa trên server.

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
  - **Then** có đầy đủ: Tên ứng dụng (*"Sân 7 – Cáp kèo, Đặt sân & Quản lý đội"*), mô tả ngắn (80 ký tự), mô tả chi tiết (≤ 4.000 ký tự), bộ từ khoá, App Icon 1024×1024px không nền trong suốt, Feature Graphic 1024×500px (Google Play), bộ 6 ảnh chụp màn hình tiếng Việt có dấu chuẩn, bảng khai báo Data Safety / App Privacy và tài khoản demo cho người duyệt bài của Apple/Google.
- **AC2 (Đóng gói bản ký số Release):**
  - **Given** mã nguồn trên nhánh phát hành đã vượt qua `flutter analyze`, `flutter test` và `npm test`,
  - **When** chạy lệnh đóng gói sản phẩm với biến môi trường production,
  - **Then** tạo thành công file Android App Bundle (`.aab`) được ký bằng upload keystore riêng (không dùng debug key) và gói iOS (`.ipa`) đẩy lên TestFlight / Play Console Internal Testing.

---

### US-M6-09: [Đã xong cốt lõi ở M5 — Thu nhỏ] Bổ sung Sửa/Tạm dừng lịch đăng (Màn 10) & Nhãn lịch tự đăng (Màn 18)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `2 SP` (~0,5 ngày, giảm từ 5 SP) | **Cần anh Duy:** Không
- **Trạng thái từ M5 (Đã hoàn thành phần cốt lõi):**
  - Backend `GET /v1/teams/:teamId/post-schedules` (chỉ cho phép `captain` và `vice`, chỉ trả lịch `status = 'scheduled'`, không trả lịch đã huỷ), `POST /v1/teams/:teamId/post-schedules` và `DELETE /v1/teams/:teamId/post-schedules/:id` **đã làm xong ở M5** (commit `3abba24`).
  - UI chọn chế độ `"Hẹn lịch"` / `"Lặp hàng tuần"` trên Màn 2 và danh sách + tạo/huỷ lịch đăng trong tab `"Lịch đăng"` của Màn 10 **đã làm xong ở M5**.
  - Do đó, `US-M6-09` được thu nhỏ lại chỉ còn phần chỉnh sửa/tạm dừng lịch đăng mà không cần xoá tạo lại và hiển thị nhãn liên kết trên Màn 18.

**User Story:**
- **As a** Đội trưởng hoặc Đội phó,
- **I want** tạm dừng tuần kế tiếp hoặc sửa giờ đăng của lịch hẹn định kỳ ngay trên tab `"Lịch đăng"` (Màn 10) và thấy nhãn `"Kèo đang tự đăng theo lịch"` tại mục Sắp tới của Màn 18,
- **So that** tôi điều chỉnh nhanh khi đội nghỉ đột xuất 1 tuần mà không phải xoá lịch đi tạo lại từ đầu.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Sửa / Tạm dừng lịch đăng trên Màn 10):**
  - **Given** đội đang có lịch hẹn đăng kèo (`status = 'scheduled'`) trong tab `"Lịch đăng"` của Màn 10 (chỉ hiển thị cho `captain` và `vice`),
  - **When** `captain` hoặc `vice` bấm `"Sửa"` hoặc `"Tạm dừng"`,
  - **Then** ứng dụng gọi `PATCH /v1/teams/:teamId/post-schedules/:scheduleId` để cập nhật giờ/nội dung hoặc bỏ qua kỳ kế tiếp mà không làm mất cấu hình lặp tuần.
- **AC2 (Nhãn lịch tự đăng trên Màn 18 & Đồng bộ số đếm tab Màn 10):**
  - **Given** người dùng mở Màn 18 (`schedule_page.dart`) và Màn 10 (`my_posts_screen.dart`),
  - **When** đội có buổi đá gắn với lịch tự đăng kèo,
  - **Then** trên Màn 18 hiển thị dòng `"Kèo đang tự đăng theo lịch · Xem kèo"`; trên Màn 10 cả 3 tab hiển thị đầy đủ số đếm (`Đang mở · N`, `Lịch đăng · N`, `Đã chốt · N`).

---

### US-M6-10: Hoàn thiện Chat Màn 21 (\"Chốt kèo\", \"Đã xem\", header) & Nối nút \"Nhắn tin\" từ Màn 9, 13, 22 + nút \"Hoàn tác\"
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Đội trưởng hoặc Đội phó đang thương lượng kèo với đội bạn trên Màn 21 (hoặc từ Màn 9, 13, 22),
- **I want** mở thẳng phòng chat từ màn Xác nhận đối (Màn 9), Gửi nhận kèo (Màn 13), Hồ sơ đội (Màn 22), thấy trạng thái `"Đã xem"` dưới tin nhắn, bấm `"Chốt kèo"` ngay trên thẻ ghim đầu phòng chat, và có nút `"Hoàn tác"` khi lỡ bấm từ chối ở Màn 9,
- **So that** trải nghiệm thương lượng và chốt trận giữa hai đội khớp 100% với bản vẽ thiết kế `san7-ui.html`.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Nút \"Chốt kèo\", trạng thái \"Đã xem\" và Header Màn 21 theo bản vẽ):**
  - **Given** người dùng mở Màn 21 (`ChatScreen`),
  - **When** quan sát thanh tiêu đề, thẻ kèo ghim đầu trang và tin nhắn cuối cùng do mình gửi,
  - **Then** thanh tiêu đề hiển thị avatar đội bạn kèm dòng phụ đề tên đội trưởng & điểm uy tín; thẻ ghim hiển thị trạng thái kèo/trận và nút `"Chốt kèo"` (nếu kèo đang ở bước thương lượng chờ xác nhận và người dùng là `captain`/`vice` chủ kèo); tin nhắn đã được đối phương mở xem hiển thị nhãn `"Đã xem"` (qua sự kiện `chat.read` / `lastReadAt`).
- **AC2 (Nối nút \"Nhắn tin\" ở Màn 9, 13, 22):**
  - **Given** hai đội đã có trận đấu chung hoặc yêu cầu nhận kèo đang mở,
  - **When** người dùng bấm nút `"Nhắn tin"` trên Màn 9 (`request_detail_screen.dart`), Màn 13 (`send_request_screen.dart`) hoặc Màn 22 (`team_profile_screen.dart`),
  - **Then** ứng dụng điều hướng thẳng vào Màn 21 (`ChatScreen`) thay vì hiện thông báo *"Nhắn tin giữa các đội có ở bản sau"*.
- **AC3 (Hoàn tác thao tác trên Màn 9):**
  - **Given** chủ kèo vừa bấm `"Từ chối"` một yêu cầu nhận kèo trên Màn 9,
  - **When** thanh thông báo kèm nút `"Hoàn tác"` hiện lên trong 5 giây và người dùng bấm `"Hoàn tác"`,
  - **Then** yêu cầu được khôi phục về trạng thái chờ (`pending`) trước khi thông báo từ chối gửi đi.

---

### US-M6-11: Gia cố bảo mật & độ tin cậy Backend từ `m5-review.md` (Các mục \"Nên sửa\" & \"Gợi ý\")
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Kỹ sư Backend & Bảo mật (Teamlead / Backend Dev),
- **I want** khắc phục triệt để các hạng mục *"Nên sửa"* và *"Gợi ý"* còn lại trong báo cáo `docs/reviews/m5-review.md` và `docs/reviews/m5-security-review.md`,
- **So that** hệ thống chống được tấn công spam WebSocket, đảm bảo toàn vẹn khóa ngoại DB, đồng bộ bình luận/cảm xúc realtime và bộ test E2E phản ánh đúng cơ chế phân quyền thực tế.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Socket.IO CORS Allowlist, Rate Limit & Join Room `post:{postId}` — Nên sửa #1, #5 & Thấp T1):**
  - **Given** cấu hình `RealtimeGateway` (`/v1/socket`),
  - **When** client kết nối và gửi các sự kiện `team:join`, `match:join`, `post:join`,
  - **Then** CORS chỉ cho phép các origin trong allowlist cấu hình (không để `origin: true` ở production); có bộ giới hạn tần suất (rate limit) theo socket/`userId` cho sự kiện join/leave và giới hạn số room tối đa trên mỗi socket; bổ sung sự kiện `post:join` / `post:leave` có kiểm tra hợp lệ để client nhận được `comment.created`, `comment.deleted`, `reaction.changed`; ghi log có cấu trúc khi truy vấn DB lúc join gặp lỗi thay vì nuốt lỗi im lặng.
- **AC2 (Ràng buộc FK & Index cho bảng Chat và Reaction — Nên sửa #3 & Gợi ý):**
  - **Given** schema Prisma của `MatchMessage` và `Reaction`,
  - **When** tạo migration bổ sung cho M6,
  - **Then** bảng `match_messages` có đầy đủ khóa ngoại `team_id -> teams(id)` và index trên `team_id`, `user_id`; bổ sung cơ chế dọn dẹp (`cleanup`) các bản ghi `reactions` mồ côi khi xoá `post` hoặc `comment`.
- **AC3 (Đồng bộ lịch đăng với hàng đợi, xử lý `bookingId` & Chủ động huỷ lịch khi hạ quyền — Nên sửa #2, V4, V5):**
  - **Given** Đội trưởng gọi `remove`, `leave` hoặc `changeRole` hạ quyền một `vice` xuống `member`/`treasurer`,
  - **When** thao tác nhân sự hoàn tất,
  - **Then** hệ thống chủ động chuyển ngay các `post_schedules` đang `scheduled` của người đó sang `cancelled` và gỡ job BullMQ (không đợi tới lúc tới giờ đăng worker mới huỷ); đồng thời xác thực quyền sở hữu `bookingId` nếu truyền vào lịch đăng (hoặc loại bỏ `bookingId` khỏi lịch lặp tuần) và có job đối soát (reconciliation) các lịch `scheduled` bị mất job trên Redis.
- **AC4 (Validation DTO Bình luận/Cảm xúc, Swagger lỗi Chat & E2E Guard thật — Nên sửa #6, Gợi ý & Thấp T2, T3):**
  - **Given** bộ kiểm thử E2E (`chat.e2e-spec.ts`, `media.e2e-spec.ts`, `schedules.e2e-spec.ts`) và DTO cộng đồng,
  - **When** chạy `npm run test:e2e`,
  - **Then** có bài test chạy với `JwtAuthGuard` và `TeamMemberGuard` thật (không override bằng guard giả) kiểm chứng đủ các mã `401`, `403` (outsider, member `pending`, member vừa bị `remove`, `member` gọi endpoint của `captain`/`vice`) và `429` (rate limit bằng Redis); `CreateCommentDto.body` có `@MinLength(1)` sau `@Trim()`; `removeReaction` gọi `ensurePost(postId)` trước khi xoá; Swagger của `/v1/matches/{matchId}/messages` khai báo đủ mã lỗi `400/401/403/404/409/429`.

---

### US-M6-12: Đóng các mục lệch mức Vừa luồng Đặt sân (kèm bộ seed 184 sân thật OpenStreetMap & ghi công ODbL), Kết quả & Đội bóng (Màn 3, 4, 6, 12, 16, 17, 19, 20, 22)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** **CÓ** (Bổ sung **giá thuê sân thật, khung giờ hoạt động và SĐT chủ sân** cho các sân trong bộ seed 184 sân OSM)
- **Ghi chú cập nhật về dữ liệu sân thật (`seed-du-lieu`):**
  - Trên nhánh `seed-du-lieu` (commits `5200e93`, `beb3887`, `4200c6d`), đội kỹ thuật đã xây dựng bộ nạp và cache **184 sân bóng thật** tại Hà Nội & TP. Hồ Chí Minh từ **OpenStreetMap** (`prisma/seed-data/osm/`, chạy qua `npm run import:osm` với khoá `osm_id` chống trùng lặp).
  - Dữ liệu OpenStreetMap tuân thủ giấy phép **ODbL**, bắt buộc hiển thị ghi công **`"© OpenStreetMap contributors"`** trong ứng dụng.
  - Tuy nhiên, dữ liệu OSM hiện **còn thiếu bảng giá thật, khung giờ mở cửa chi tiết và SĐT liên hệ chủ sân** (hiện đang phải gắn cờ `price_estimated = true` với 3 khung giờ ước lượng `18:00`, `19:30`, `21:00` và nhiều bản ghi `phone = null`, `opening_hours = null`).

**User Story:**
- **As a** Thành viên đội bóng tìm và đặt sân,
- **I want** tra cứu được danh sách 184 sân bóng thật từ OpenStreetMap (kèm ghi công `"© OpenStreetMap contributors"` đúng giấy phép ODbL và nhãn phân biệt rõ giá chính thức hay giá ước lượng), lọc bản đồ sân theo ngày/loại sân, xem đủ tiện ích/ảnh/SĐT sân, chia sẻ vé đặt sân, gắn chip nhận xét đối thủ sau trận (Màn 17, 22), xem tiến độ đóng quỹ kèm avatar và quét mã QR mời vào đội (Màn 12),
- **So that** tôi tìm được sân bóng thực tế quanh mình với thông tin minh bạch và mọi thao tác khớp với bản vẽ.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Hợp nhất bộ seed 184 sân thật từ nhánh `seed-du-lieu`, hiển thị ghi công ODbL `"© OpenStreetMap contributors"` & Bổ sung Giá/Khung giờ/SĐT):**
  - **Given** nhánh `seed-du-lieu` đã có bộ seed 184 sân bóng thật từ OpenStreetMap (`source = 'osm'`, `osm_id`),
  - **When** hợp nhất vào nhánh phát hành và mở Màn 3 (Bản đồ/Danh sách sân), Màn 4 (Chi tiết sân) hoặc Màn 23 (Giới thiệu),
  - **Then** ứng dụng hiển thị rõ dòng ghi công **`"© OpenStreetMap contributors"`** theo đúng giấy phép ODbL; đối với các sân chưa được anh Duy cập nhật giá thật (`price_estimated = true`), UI hiển thị nhãn `"Giá tham khảo"` và ẩn/khoá nút gọi điện nếu `phone = null`; khi có dữ liệu bảng giá thật, khung giờ (`slots`, `opening_hours`) và SĐT (`phone`) từ anh Duy, script seed cập nhật đầy đủ và chuyển `price_estimated = false`.
- **AC2 (Màn 3, 4, 16 - Đặt sân):**
  - **Given** người dùng mở Màn 3, Màn 4 và Màn 16,
  - **When** tìm kiếm và đặt sân,
  - **Then** Màn 3 giữ nền OpenStreetMap, bổ sung chip lọc ngày (`Hôm nay`...) và `"Sân 7"`; Màn 4 hiển thị số lượng ảnh, điểm đánh giá, chip tiện ích (`cỏ mới`, `đèn LED`, `gửi xe`, `nước`, `phòng thay đồ`) và khoảng cách; Màn 16 có nút `"Chia sẻ"` vé đặt sân.
- **AC3 (Màn 17, 22 - Nhận xét sau trận & Hồ sơ đội):**
  - **Given** người dùng ở Màn 17 hoặc Màn 22,
  - **When** gửi đánh giá sau trận hoặc xem hồ sơ đội,
  - **Then** Màn 17 hiển thị nhóm 5 chip nhận xét nhanh (`Đúng giờ`, `Đá đẹp`, `Vui vẻ`, `Trả tiền sòng phẳng`, `Đủ người`) gửi vào mảng `tags` của `PUT /v1/teams/:teamId/matches/:matchId/review`; Màn 22 hiển thị dòng tổng kết `"N trận · xT yH zB"` và số đếm từng thẻ nhận xét (`Đúng giờ 31`, `Đá đẹp 24`...).
- **AC4 (Màn 6, 12, 19, 20, 23 - Đội bóng, Quỹ & Cá nhân):**
  - **Given** người dùng thao tác trên Màn 6, 12, 19, 20, 23,
  - **When** đối chiếu với bản vẽ `san7-ui.html`,
  - **Then** Màn 6 hiển thị chữ thanh tiến độ `"12/18 đã đóng"` kèm cụm avatar người chưa đóng (`+N chưa đóng`); Màn 12 tích hợp thư viện quét camera cho nút `"Quét QR"` mã mời đội; Màn 19 cập nhật dòng mô tả quyền Phó đội thành `"Phó đội: đăng kèo, hẹn lịch, đặt sân, tạo lịch, duyệt thành viên"`; Màn 20 đổi nhãn `"Gắn với lịch"` thành `"Gắn với trận"`; Màn 23 có dòng `"+ Tạo hoặc tham gia đội khác"` và icon màu đúng bản vẽ.

---

### US-M6-13: Đóng các mục lệch mức Vừa luồng Bảng tin & Cáp kèo (Màn 1, 2, 11, 14)
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `5 SP` (~1,5 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Cầu thủ tìm kèo trên Bảng tin,
- **I want** tìm kiếm kèo theo từ khoá, thấy đúng nút `"Ứng tuyển"` trên thẻ tuyển người, xem thẻ kết quả trận trên Bảng tin, chọn nhanh loại kèo/sân trên bản đồ khi đăng kèo (Màn 2) và lọc/so sánh các đội nhận kèo theo khoảng cách địa lý (Màn 11),
- **So that** giao diện khớp hoàn toàn với bản vẽ thiết kế và giúp tôi chọn đối thủ gần sân nhất.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Màn 1 - Bảng tin):** Có nút Tìm kiếm trên thanh tiêu đề đầu trang; thẻ loại `"Tuyển người"` (`recruit`) hiển thị nút `"Ứng tuyển"` kèm các chip vị trí cần tuyển (`Thủ môn`, `Hậu vệ`, `Tiền vệ`, `Tiền đạo`); hiển thị thẻ bài kết quả trận đấu (`3–2`, người ghi bàn, MVP).
- **AC2 (Màn 2 - Đăng kèo mới):** Có nhóm chọn loại hình tiền sân rõ ràng (`Chia tiền sân` / `Thua trả sân` / `Kèo nước` / `Giao hữu`), nút `"Tìm trên bản đồ"` + tuỳ chọn `"Chưa có sân"`, và dòng tự động tính nhẩm tiền sân theo tỷ lệ (`"Sân 600.000đ · Thắng trả 240.000đ · Thua trả 360.000đ"`).
- **AC3 (Màn 11 & Màn 14 - So sánh đội & Chi tiết kèo):** Màn 11 bổ sung hàng `"Khoảng cách"` (tính theo km từ khu vực/sân) và đủ bộ 3 chip lọc `"Uy tín cao"` / `"Gần nhất"` / `"Đăng ký sớm"`; Màn 14 hiển thị thẻ sân kèm nút `"Chỉ đường"`, khối `"Đội hình"` và dòng tổng hợp `"N đội đã gửi nhận kèo"`.

---

### US-M6-14: Rà soát vùng bấm 44×44px, tương phản AA, trạng thái mất mạng/loading & sửa đơ khung hình sau khi lưu
- **Phân loại MoSCoW:** `Should Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** **CÓ** (Chốt kiểu hiển thị Toast)

**User Story:**
- **As a** Người dùng sử dụng ứng dụng ngoài sân bóng (ánh sáng mạnh, mạng 4G chập chờn),
- **I want** mọi nút bấm đều đủ lớn (tối thiểu 44×44px), độ tương phản chữ đạt chuẩn WCAG AA, màn hình đóng/chuyển mượt ngay sau khi bấm Lưu (không bị đơ khung hình chờ chạm lại), và ứng dụng thông báo rõ khi mất mạng,
- **So that** tôi không bấm nhầm và luôn biết trạng thái của ứng dụng.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Vùng bấm & Tương phản):** Rà soát toàn bộ 24 màn mobile đảm bảo mọi `IconButton`, `TextButton`, `Pill`, chip lọc đều có vùng chạm `>= 44×44px`; không còn màu hard-code ngoài `tokens.dart`; tỷ lệ tương phản chữ/nền đạt tối thiểu `4.5:1`.
- **AC2 (Khắc phục hiện tượng đứng khung hình sau khi bấm Lưu trên máy thật):** Kiểm tra và xử lý triệt để hiện tượng sheet/màn Sửa hồ sơ đôi khi giữ nguyên khung hình sau khi `Navigator.pop` trên thiết bị Android thật (PLG110) cho tới khi người dùng chạm tay lần nữa; đồng thời dọn sạch dữ liệu test lỗi dấu trong DB dev.
- **AC3 (Trạng thái Mất mạng & Loading đồng nhất):** Mọi màn hình khi mất kết nối mạng đều hiển thị thông báo tiếng Việt thân thiện kèm nút `"Thử lại"`; mọi nút gửi biểu mẫu đều khoá (`disabled`) và hiện vòng xoay khi đang chờ API.

---

### US-M6-15: Dịch vụ thêm tại sân & tạm tính chia tiền trên màn Đặt sân (Màn 15, 16)
- **Phân loại MoSCoW:** `Could Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không

**User Story:**
- **As a** Người đặt sân (Màn 15),
- **I want** chọn thêm các dịch vụ tại sân (nước suối, thuê áo bib) và xem bảng tạm tính số tiền chia với đội đối thủ theo tỷ lệ kèo,
- **So that** tôi biết chính xác tổng số tiền cần thanh toán tại sân cho cả hai đội.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1:** Trên Màn 15, người dùng tích chọn được các dịch vụ đi kèm (nếu sân có cung cấp), hệ thống cộng vào tổng tạm tính và hiển thị khối *"Chia tiền với đội đối theo kèo"* kèm phần tiền tương ứng của mỗi đội trên Màn 15 và Màn 16.

---

### US-M6-16: Cổng thanh toán đặt cọc sân online & Bản giao diện Desktop/Web (Màn 15, D)
- **Phân loại MoSCoW:** `Won't Have (Dời sang sau M6 theo quyết định của PM & PLAN.md mục 11)` | **Ước lượng:** `13 SP` (~4 ngày) | **Cần anh Duy:** **CÓ** (Ký hợp đồng cổng thanh toán & xác nhận chủ trương bản Desktop ở giai đoạn Tăng trưởng)

**Ghi chú PO:** Theo `docs/PLAN.md` mục 2, mục 11 và quyết định đã chốt của PM Sân 7, thanh toán đặt cọc online qua cổng đối tác (Màn 15) và giao diện Desktop 3 cột (Màn D) được xếp vào giai đoạn **Sau M6 (Tăng trưởng)**. Đợt ra mắt M6 giữ phương thức trả tại sân (`deposit = 0`) và tập trung 100% cho 24 màn mobile trên Android & iOS.

---

### US-M6-17: Gắn ảnh biên lai (`receipt`) vào giao dịch Chi quỹ (Màn 20) & Xem biên lai nội bộ đội (`GET /v1/media/receipts/:id`, Màn 6)
- **Phân loại MoSCoW:** `Must Have` | **Ước lượng:** `3 SP` (~1 ngày) | **Cần anh Duy:** Không
- **Chuẩn INVEST:** Độc lập với luồng đổi Avatar (I), Thương lượng được cách xem ảnh phóng to (N), Giúp minh bạch tài chính nội bộ đội mà không lộ biên lai ra công khai (V), Ước lượng rõ 3 SP cho cả Backend `Funds` + Frontend Màn 20/Màn 6 (E), Nhỏ gọn trong 1 sprint (S), Kiểm thử được đầy đủ phân quyền `200/403/404` (T).

**User Story:**
- **As a** Đội trưởng hoặc Thủ quỹ khi ghi khoản chi quỹ ở Màn 20 (và Thành viên đội khi xem sổ quỹ ở Màn 6),
- **I want** đính kèm ảnh biên lai (`purpose = receipt`) vào giao dịch chi quỹ tại Màn 20 và cho phép các thành viên đang hoạt động trong đội bấm xem lại ảnh biên lai qua đường dẫn bảo mật `GET /v1/media/receipts/:id`,
- **So that** mọi khoản chi tiêu của đội đều có chứng từ minh bạch cho anh em trong đội kiểm tra nhưng người ngoài đội không thể truy cập được ảnh biên lai.

**Tiêu chí nghiệm thu (Given / When / Then):**
- **AC1 (Tải lên & xác minh ảnh biên lai gắn với đội ở Màn 20):**
  - **Given** Đội trưởng (`captain`) hoặc Thủ quỹ (`treasurer`) đang ở tab `"Chi"` trên Màn 20 (`add_fund_tx_screen.dart`),
  - **When** bấm ô `"Thêm ảnh"` tại mục `"Ảnh hoá đơn"`, chọn/chụp một ảnh biên lai,
  - **Then** ứng dụng chuyển định dạng sang `image/jpeg` hoặc `image/webp` + nén ảnh, gọi `POST /v1/media/uploads` với `{ purpose: 'receipt', teamId, contentType, size }`, `PUT` bytes lên `uploadUrl`, và gọi `POST /v1/media/uploads/finalize` (`{ key }`) để nhận về `{ key, url: '/v1/media/receipts/:id' }` kèm hiển thị ảnh xem trước (preview) và nút xoá/chọn lại trên Màn 20.
- **AC2 (Lưu biên lai vào giao dịch Chi quỹ tại `POST /v1/teams/:teamId/funds/transactions`):**
  - **Given** người dùng đã đính kèm ảnh biên lai hợp lệ trên Màn 20 và điền số tiền, hạng mục chi,
  - **When** bấm `"Lưu khoản chi"`,
  - **Then** `CreateFundTxDto` / `POST /v1/teams/:teamId/funds/transactions` nhận `receiptKey` (hoặc `receiptUrl` đã qua `finalize` thuộc đúng `teamId` và `ownerId`), lưu vào bản ghi giao dịch quỹ (`fund_transactions`) và trả về trường `receiptUrl` (`/v1/media/receipts/:id`) trong `FundTxDto` (cả ở `GET /v1/teams/:teamId/funds/transactions` và `GET /v1/teams/:teamId/funds/summary`).
- **AC3 (Chỉ thành viên trong đội mới xem được ảnh biên lai qua `GET /v1/media/receipts/:id` trên Màn 6):**
  - **Given** một giao dịch chi quỹ có đính kèm `receiptUrl` (`/v1/media/receipts/:id`),
  - **When** thành viên `active` của đội bấm vào dòng giao dịch hoặc biểu tượng biên lai trên Màn 6 (`funds_page.dart`),
  - **Then** ứng dụng gửi request `GET /v1/media/receipts/:id` kèm header `Authorization: Bearer <accessToken>` để hiển thị ảnh biên lai WebP (`Cache-Control: private, no-store`); nếu người gọi chưa đăng nhập trả `401`, nếu không phải thành viên `active` của đội trả `403 media_forbidden` (*"Chỉ thành viên đội được xem biên lai"*), và tuyệt đối không đọc được biên lai qua đường dẫn công khai `/v1/media/public/:id` (`404 media_not_found`).
