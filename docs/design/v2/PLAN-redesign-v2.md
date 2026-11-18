# Kế hoạch nâng cấp giao diện v2 "Floodlight Night" (18/11/2026)

Nguồn: 2 bản vẽ anh Duy gửi 18/11 (Phần 1 và Phần 2, 40 màn). Bản vẽ từng màn được tách ra trong thư mục này, mỗi file `NN-ten-man.html` mở thẳng bằng trình duyệt. Chữ của mọi màn có trong `screens-text.txt`. Các file `.html` chỉ để ở máy, không commit vì nặng 37 MB.

Nhánh làm việc: `m6-ra-mat`, dùng chung một bản checkout, nên **mỗi người chỉ commit file của mình**. Không push.
Quy trình gọn: không QA, không review. Dev chỉ cần `flutter analyze` hoặc `npm run build` pass và app mở được.

## 1. Nhận diện mới (màn 00)
- **Màu:**

  | Tên | Mã | Dùng cho |
  |---|---|---|
  | Lime đèn pha | `#C8FF2E` | màu chính, nút |
  | Sân đêm | `#06110B` | nền |
  | Cỏ | `#11402A` | thẻ, bề mặt |
  | Kèo nóng | `#FF6B2C` | |
  | Cúp vàng | `#FFC83D` | |
  | Đội nhà | `#2F7BFF` | |

- **Chữ:**
  - **Barlow Condensed ExtraBold Italic:** tiêu đề, tỉ số, con số.
  - **Be Vietnam Pro:** nội dung.
  - Cả hai đóng gói font vào `assets/`, không tải mạng lúc chạy.
- **Thành phần dùng chung:**
  - phù hiệu đội dạng khiên (chữ viết tắt + màu áo);
  - thẻ "vé vào trận";
  - chip trạng thái (KÈO NÓNG, TUYỂN NGƯỜI, KẾT QUẢ, LIVE);
  - thanh tab dưới 4 mục: Bảng tin / Đặt sân / Đội / Bảng vàng;
  - dải LIVE chạy chữ;
  - đồng hồ đếm ngược;
  - icon nét cho thao tác.
- **Chuyển động** (đèn pha quét, bóng nảy, thẻ trồi lên) làm nhẹ, có thể bỏ nếu tốn công.

## 2. Phân loại 40 màn
**Đổi giao diện, đã có API (26 màn):**
- **Cáp kèo:**
  - 01 Bảng tin
  - 03 Chi tiết kèo
  - 10 Đăng kèo
  - 11 Gửi nhận kèo
  - 12 Xác nhận đối
  - 13 So sánh đội
  - 14 Kèo của tôi
  - 15 Thông báo
  - 16 Chat
  - 17 Hồ sơ đội khác
  - 18 Cảm xúc
- **Đặt sân:**
  - 04 Bản đồ
  - 05 Chi tiết sân
  - 19 Xác nhận đặt và cọc
  - 06 Đặt thành công
  - 31 Lịch sử đặt sân
- **Đăng nhập và hồ sơ:**
  - 02 Chào mừng
  - 27 Hồ sơ cầu thủ
  - 28 Vào/tạo đội
  - 24 Cá nhân
- **Đội:**
  - 07 Đội bóng
  - 20 Lịch và điểm danh
  - 21 Thành viên
  - 22 Quỹ
  - 23 Thêm khoản
- **Sau trận:**
  - 09 Kết quả trận
  - 08 Bảng vàng

**Màn hoặc phần mới, cần thêm backend:**

| Màn | Việc mới | Backend |
|---|---|---|
| 01 | Dải LIVE, khối "Sân trống tối nay", đếm ngược "tự huỷ sau" | API sân trống quanh tôi theo giờ |
| 17 | Theo dõi đội, nhận xét theo thẻ, phong độ 5 trận, tỉ lệ đúng giờ và giữ kèo | follow, thống kê đội |
| 19, 36 | Cọc qua chuyển khoản VietQR, mã nội dung, giữ sân đếm ngược | thông tin tài khoản sân, `deposit_claimed` |
| 21 | Chờ duyệt vào đội, phân quyền thủ quỹ/phó đội, tạo mã mời mới | yêu cầu vào đội, đổi vai trò |
| 26 | Danh sách tin nhắn, số chưa đọc | API hộp thư |
| 29 | Tìm kiếm chung: đội, sân, kèo, cầu thủ | `/v1/search` |
| 30 | Bộ lọc kèo: km, ngày, khung giờ, trình độ, uy tín | tham số lọc cho feed |
| 31 | Thống kê năm (số lần đặt, số giờ, tiền, sân hay đặt) | tổng hợp |
| 32 | Đánh giá sân theo 4 tiêu chí kèm thẻ | model `PitchReview` |
| 33 | Hồ sơ cầu thủ khác, đối đầu với tôi | API hồ sơ công khai |
| 34 | Trạng thái mất mạng, lỗi 500, rỗng, đang tải | chỉ app |
| 35 | Xác nhận hoặc đề xuất lại tỉ số kèm người ghi bàn | dùng `Match.confirmedAt`, bổ sung đề xuất lại |
| 37 | Onboarding quyền vị trí và thông báo | chỉ app |
| 38 | Báo cáo đội, chặn đội | model `TeamReport`, `TeamBlock`, ẩn nội dung đội bị chặn |
| 39 | Bình chọn MVP có thời hạn | model `MvpVote` |
| 40 | Thành viên đóng quỹ qua VietQR tới thủ quỹ, "Tôi đã chuyển" | tài khoản thủ quỹ, yêu cầu đóng quỹ chờ duyệt |
| 08 | Sổ phạt trong Bảng vàng, danh hiệu đội | API sổ phạt (đã có `FineRule`) |

## 3. PM chốt
- **Thanh toán:** chưa có cổng thanh toán, vì cần tài khoản và tiền của anh Duy.
  - **QR:** app tự sinh mã VietQR chuẩn EMVCo trên máy (gói `qr_flutter`) từ số tài khoản và nội dung chuyển khoản, không gọi dịch vụ ngoài.
  - **"Kiểm tra" / "Tôi đã chuyển":** chuyển trạng thái sang `deposit_claimed` (cọc sân) hoặc `pending` (đóng quỹ). Đội trưởng hoặc thủ quỹ bấm xác nhận.
  - **Ngân hàng:** chưa tự đối soát với ngân hàng.
- **Apple:** nút "Tiếp tục với Apple" chỉ hiện trên iOS và ẩn trên Android, cho tới khi có tài khoản Apple.
- **Màn 33:** biểu đồ "Chỉ số do đồng đội chấm" để đợt sau. Đợt này hiện số liệu thật (trận, bàn, kiến tạo, MVP, phong độ, đối đầu).
- **Dữ liệu:** chỉ hiện dữ liệu thật, không có thì hiện trạng thái rỗng như màn 34. Seed demo bổ sung để màn nào cũng có dữ liệu.
- **Giữ nguyên** logic và luồng đã chạy. Đây là đổi giao diện cộng thêm tính năng, không viết lại.

## 4. Chia việc

| Đợt | Người | Việc |
|---|---|---|
| A (ngay) | Frontend luồng 1 | Nền tảng: tokens màu, font, theme tối, thanh tab, bộ widget dùng chung, màn 34 (trạng thái) |
| A (ngay) | Backend luồng 1 | Đặt sân: 01 sân trống tối nay, 19/36 cọc VietQR, 31 thống kê, 32 đánh giá sân |
| A (ngay) | Backend luồng 2 | Đội và sau trận: 21 duyệt vào đội và vai trò, 40 đóng quỹ, 35 đề xuất lại tỉ số, 39 MVP, 08 sổ phạt, 33 hồ sơ cầu thủ |
| A (ngay) | Backend luồng 3 | Tiện ích và an toàn: 29 tìm kiếm, 30 bộ lọc, 26 hộp thư, 17 theo dõi và thống kê đội, 38 báo cáo/chặn |
| B (sau khi nền tảng xong) | Frontend luồng 2 | Phần 1 cáp kèo: 01, 03, 10, 11, 12, 13, 14, 15, 16, 17, 18, 26 |
| B | Frontend luồng 3 | Phần 1 đặt sân: 04, 05, 19, 36, 06, 31, 32 |
| B | Frontend luồng 4 | Phần 2: 02, 27, 28, 37, 07, 20, 21, 22, 23, 40, 09, 35, 39, 08, 24, 29, 30, 33, 38 |

**Thứ tự trong đợt B:**
- **Màn chưa có API:** Frontend dựng giao diện với dữ liệu giả theo hợp đồng ở mục 2, nối API thật khi Backend commit.
- **Backend:** mỗi phần một commit kèm `docs/openapi.json` sinh lại. Frontend sinh client bằng `scripts/gen-api-client.ps1`.
- **Cuối mỗi luồng:** build APK theo `app/README.md` (mục "Điện thoại cắm USB") để anh Duy test trên máy thật.
