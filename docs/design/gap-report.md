# Báo cáo lệch: app Flutter so với bản vẽ (24 màn mobile + 1 desktop)

- Ngày rà: 16/11/2026. Người rà: Frontend Dev.
- Bản vẽ: `docs/design/san7-ui.html`. Đánh số 1–24 theo tiêu đề trong bản vẽ ("N · Tên màn").
- Phạm vi: chỉ rà soát, **không sửa code**. App ở `app/lib` (không tính `app/lib/api/`).
- Cách rà: giải nén từng màn của bản vẽ, lấy toàn bộ chữ, nút, khối giao diện. Sau đó đối chiếu với route trong `core/router/app_router.dart` và chữ/widget trong từng file màn.
- **Giới hạn (chưa kiểm tra):** đây là rà tĩnh theo mã nguồn. Chưa so từng pixel trên máy hay trình duyệt, nên **màu, khoảng cách, cỡ chữ chi tiết chưa được xác nhận**. Các mục "cần xác minh" ghi rõ bên dưới. Chưa chụp ảnh tham chiếu `docs/design/screens/` (thư mục đã tạo, đang trống).
- Mức: **Nặng** = thiếu màn hoặc thiếu luồng. **Vừa** = sai bố cục, thiếu nút hoặc khối. **Nhẹ** = chữ, màu, khoảng cách.
- "M5" và "M6" là mốc trong `docs/PLAN.md` mục lộ trình. Chỗ lệch do mốc chưa tới được đánh dấu "(đã nằm trong M5/M6)".

## Tóm tắt

| Mức | Số mục |
|---|---|
| Nặng | 9 (4 màn chưa có, 1 desktop, 4 thiếu luồng hoặc khối lớn trong màn đã có) |
| Vừa | 19 (17 trong bảng màn, 2 xuyên suốt) |
| Nhẹ | 14 (11 trong bảng màn, 3 xuyên suốt) |

- **Có màn trong app:** 20/24 màn mobile (có file, có route), trong đó màn 14 và 15 mới có một phần. 15 màn còn lệch ở mức Vừa trở lên.
- **Chưa có màn:** 4/24 màn mobile (10, 21, 23, 24) cùng bản desktop. Phần bình luận/cảm xúc của màn 14 cũng thiếu. Gần như toàn bộ nằm trong M5 (PLAN dòng 234). Backend (`app/lib/api/`) cũng chưa có API bình luận, cảm xúc, tin nhắn, lịch lặp, nên các màn này cần Backend làm trước hoặc song song.
- Các màn M0–M4 (đăng nhập, bảng tin, nhận kèo, đặt sân, đội, quỹ, kết quả trận) đã có khá đủ, lệch chủ yếu ở nút/khối phụ.

## Bảng theo màn

| # | Màn (bản vẽ) | Trạng thái và file | Chỗ lệch | Mức |
|---|---|---|---|---|
| 1 | Bảng tin cáp kèo | **Có**: `features/feed/presentation/feed_screen.dart`, thẻ kèo ở `features/posts/presentation/post_widgets.dart` | Thiếu: nút Tìm kiếm trên đầu trang (chỉ có chuông và avatar); ảnh/video trong thẻ (khối 2 ô ảnh, nhãn video 0:24, "+1"); dòng cảm xúc và số bình luận; thanh Bình luận, Chia sẻ và bộ chọn cảm xúc Thích/Tim/Đỉnh/Haha/Tiếc (đã nằm trong M5) | Nặng |
| | | | Thẻ "Tuyển người" dùng nút "Nhận kèo", bản vẽ là "Ứng tuyển" kèm chip vị trí (Thủ môn, Tiền vệ) (cần xác minh chip vị trí) | Vừa |
| | | | Thẻ "Kết quả" (3–2, bàn thắng, cầu thủ hay nhất) chưa thấy trong code feed (cần xác minh loại bài `result`) | Vừa |
| | | | Đầu trang có chọn khu vực theo bottom sheet, bản vẽ không có. Ngày "Thứ Bảy, 14 tháng 11" có, cần so cỡ chữ 34/13 và chữ in hoa | Nhẹ |
| 2 | Đăng kèo mới | **Có**: `features/post_create/presentation/post_create_screen.dart` | Thiếu: ảnh & video (đã nằm trong M5); "Thời điểm đăng" Đăng ngay/Hẹn lịch, giờ đăng, lặp hàng tuần, kết thúc sau N tuần (đã nằm trong M5) | Nặng |
| | | | Thiếu nhóm chọn loại kèo (Chia tiền sân / Thua trả sân / Kèo nước / Giao hữu); chưa thấy nút "Tìm trên bản đồ" và trạng thái "Chưa có sân"; app thay bằng ô nhập tên sân; thiếu dòng tính tiền "Sân 600.000đ, thắng trả, thua trả" | Vừa |
| | | | Thiếu dòng chú thích "Kèo sẽ hiện trên Bảng tin trong bán kính 5 km"; chữ chú thích tỷ lệ cần so lại | Nhẹ |
| 3 | Bản đồ đặt sân | **Có**: `features/pitches/presentation/pitches_screen.dart` | Nền bản đồ OpenStreetMap, bản vẽ ghi "Google Maps" (placeholder, cần PO chốt) | Nhẹ |
| | | | Bộ lọc: bản vẽ là Hôm nay / 19:00–20:30 / Sân 7 / Có đèn / Dưới 1 km. App có Mọi giờ / Có đèn / Dưới 1 km / Gần tôi, chưa thấy chip ngày và chip "Sân 7" | Vừa |
| | | | Đã đủ: ghim kèm số chỗ trống, danh sách, thẻ trượt "Xem sân & đặt", trạng thái trống/lỗi/thử lại. Cần so lại màu ghim "hết" | Nhẹ |
| 4 | Chi tiết sân & chọn giờ | **Có**: `features/pitches/presentation/pitch_detail_screen.dart`, `pitch_widgets.dart` | Chưa thấy trong chữ code: thư viện ảnh "8 ảnh", dòng điểm đánh giá 4,8 (230), chip tiện ích (cỏ mới, đèn LED, gửi xe, nước, phòng thay đồ), dòng "1,2 km · 6 phút đi xe máy". Cần mở trên máy để xác minh có nằm trong dữ liệu API không | Vừa |
| | | | Có: chọn ngày, khung giờ, nút Chỉ đường, nút Đặt sân, trạng thái hết sân/đã qua | — |
| 5 | Đội bóng & thành tích | **Có**: `features/team/presentation/team_screen.dart` (tab Tổng quan), khung `team_page_scaffold.dart` | Có thống kê, 5 trận gần nhất, trận tới, điểm danh, thành viên. Cần so lại khiên đội, thanh tab Tổng quan/Thành viên/Lịch/Quỹ | Nhẹ |
| 6 | Quỹ đội | **Có**: `features/funds/presentation/funds_page.dart`, `fund_widgets.dart` | Nút "Nhắc đóng quỹ" mới báo "sẽ có ở bản sau" (cần thông báo đẩy). Chưa thấy chữ thanh tiến độ "12/18 đã đóng", avatar người chưa đóng, "+3 chưa đóng" (chỉ thấy "chưa đóng") | Vừa |
| 7 | Vinh danh & sổ phạt | **Có**: `features/honors/presentation/honors_screen.dart` | Có Cầu thủ của tháng, Vua phá lưới, Danh hiệu, Sổ phạt, Luật phạt, chọn tháng, đánh dấu đã nộp. Chưa thấy chip MVP/Vua phá lưới/Tất cả và nhóm 3 số Bàn/Kiến tạo/MVP trong thẻ đầu (cần xác minh) | Nhẹ |
| 8 | Thông báo | **Có**: `features/notifications/presentation/notifications_screen.dart` | Có tab Tất cả/Kèo/Đặt sân/Đội/Quỹ, nhóm Hôm nay/Trước đó, đếm ngược tự huỷ, nút "Xem & xác nhận". Chưa thấy dòng hành động phụ "Nhập kết quả", "Sửa lịch" (cần xác minh) | Nhẹ |
| 9 | Xác nhận đối nhận kèo | **Có**: `features/posts/presentation/request_detail_screen.dart` | Thiếu nút "Nhắn tin" (chat nằm ở M5) và "Hoàn tác" sau khi chốt/từ chối | Vừa |
| | | | Có: thẻ đội đối, uy tín, đúng giờ, thông tin kèo, Chấp nhận/Từ chối, so sánh, xem lịch đội, đếm ngược | — |
| 10 | Kèo của tôi & lịch đăng | **Chưa có** (không có file, không có route) | Cả màn: tab Đang mở/Lịch đăng/Đã chốt, thẻ lịch lặp (Bỏ qua, Khôi phục, Sửa, Tạm dừng, Xoá), thẻ "3 đội muốn nhận" dẫn sang so sánh. Cần API lịch đăng (đã nằm trong M5). Hiện chỉ có trang chi tiết kèo `post_detail_screen.dart` | Nặng |
| 11 | So sánh đội nhận kèo | **Có**: `features/posts/presentation/compare_requests_screen.dart` | Thiếu hàng "Khoảng cách" (4,1 km, 2,0 km, 5,6 km) và chip lọc "Uy tín cao / Gần nhất / Đăng ký sớm" (app chỉ có nhãn "Đã đá nhiều nhất", "Đăng ký sớm"). Cần API khoảng cách | Vừa |
| | | | Có: bảng so sánh, nhãn "Phù hợp nhất", lời nhắn, nút Chọn, chú thích cuối | — |
| 12 | Đăng nhập Google & vào đội | **Có**: `features/auth/presentation/onboarding_screens.dart` (Welcome, Profile, Team step) | "Quét QR" mới báo "sẽ có ở bản sau" (cần thư viện quét QR). "Tiếp tục với Apple" chỉ hiện nhãn (đã nằm trong M6) | Vừa |
| | | | Có: Google, hồ sơ cầu thủ (tên, vị trí, số áo, khu vực), tham gia/tạo đội, trình độ, "Để sau, xem Bảng tin trước", điều khoản. Cần so chữ tiêu đề 2 dòng và icon "G" | Nhẹ |
| 13 | Gửi nhận kèo | **Có**: `features/posts/presentation/send_request_screen.dart` | Đủ khối chính (đội, số người +/−, tỷ lệ, lời nhắn, gửi, huỷ). Thiếu nút "Nhắn tin" sau khi gửi (chat nằm ở M5) | Vừa |
| 14 | Chi tiết kèo & bình luận | **Có một phần**: `features/posts/presentation/post_detail_screen.dart` | Thiếu: danh sách bình luận, ô nhập bình luận, trả lời, thích bình luận (đã nằm trong M5); bộ chọn cảm xúc; thư viện ảnh/video; khối "Đội hình" | Nặng |
| | | | Thiếu thẻ sân kèm "Chỉ đường" trong chi tiết kèo và dòng "3 đội đã gửi nhận kèo" (cần xác minh) | Vừa |
| 15 | Xác nhận đặt sân & đặt cọc | **Có một phần**: `features/pitches/presentation/booking_screen.dart` | **Luồng cọc chưa có**: app ghi "Thanh toán cọc online sẽ có ở bản sau", chỉ có "Trả tại sân". Bản vẽ có chọn phương thức thanh toán và nút "Thanh toán cọc". Cần Backend làm cổng thanh toán, quy tắc đổi trạng thái chỉ khi server xác nhận | Nặng |
| | | | Thiếu: dịch vụ thêm (nước suối, thuê áo bib), khối "Chia tiền với đội đối theo kèo", dòng tạm tính phần đội bạn | Vừa |
| | | | Có: giữ sân kèm đếm ngược, tiền sân, Huỷ giữ chỗ. Chữ nhắc "Giữ sân cho bạn trong 10 phút" cần so lại | Nhẹ |
| 16 | Đặt sân thành công | **Có**: cũng trong `booking_screen.dart` | Có mã đặt sân, Chỉ đường, Lịch đội, Đổi giờ, Huỷ đặt sân. Thiếu nút "Chia sẻ" và dòng "Còn trả tại sân" chia theo cọc (phụ thuộc luồng cọc ở màn 15) | Vừa |
| 17 | Kết quả trận & đánh giá | **Có**: `features/matches/presentation/match_result_screen.dart` | Thiếu nhóm chip nhận xét (Đúng giờ, Đá đẹp, Vui vẻ, Trả tiền sòng phẳng, Đủ người). App có sao Uy tín/Fair-play và ô nhận xét. Cần Backend có trường thẻ nhận xét (hồ sơ đội ở màn 22 đang cần số liệu này) | Vừa |
| | | | Có: tỉ số +/−, ghi bàn, kiến tạo, cầu thủ hay nhất, gửi kết quả. Chữ giải thích cuối so lại với "FC Mỹ Đình sẽ xác nhận tỉ số…" | Nhẹ |
| 18 | Lịch & điểm danh | **Có**: `features/attendance/presentation/schedule_page.dart`, `event_widgets.dart`, `create_event_screen.dart` | "Nhắc người chưa trả lời" mới báo "sẽ có ở bản sau" (cần thông báo đẩy). Thiếu hiển thị "Kèo đang tự đăng theo lịch / Xem kèo" ở mục Sắp tới (liên quan màn 10) | Vừa |
| 19 | Thành viên & mời vào đội | **Có**: `features/team/presentation/members_page.dart` | Có mã mời, tạo mã mới, QR, chia sẻ, chờ duyệt (Duyệt/Từ chối), phân quyền. Chữ mô tả quyền lệch: app "Phó đội: tạo lịch, duyệt thành viên", bản vẽ "Phó đội: đăng kèo, đặt sân". Cần PO chốt quyền thật | Nhẹ |
| 20 | Thêm khoản thu, chi hoặc phạt | **Có**: `features/funds/presentation/add_fund_tx_screen.dart` | Thiếu "Ảnh hoá đơn / Thêm ảnh" ở tab Chi (cần tải ảnh, thuộc M5). Nhãn "Gắn với lịch" so với bản vẽ "Gắn với trận" | Vừa |
| 21 | Nhắn tin giữa hai đội | **Chưa có** (không có file, không có route). `team_profile_screen.dart` hiện báo "Nhắn tin giữa các đội có ở bản sau" | Cả màn: bong bóng chat, thẻ kèo ghim, trạng thái "Chờ xác nhận", "Đã xem", nút Chốt kèo, gợi ý nhanh (Gửi vị trí sân, Đổi giờ?, Đến muộn 10 phút). Cần API tin nhắn và realtime (đã nằm trong M5; có `core/realtime/realtime_client.dart` có thể dùng) | Nặng |
| 22 | Hồ sơ đội khác | **Có**: `features/matches/presentation/team_profile_screen.dart` | Có uy tín, đúng giờ, trận gần đây, đối thủ nhận xét, Mời đá kèo. Nút "Nhắn tin" chưa nối (chờ màn 21). Thiếu dòng "38 trận · 21T 6H 11B" theo định dạng bản vẽ và nhóm đếm nhận xét (Đúng giờ 31, Đá đẹp 24…) phụ thuộc thẻ nhận xét ở màn 17 | Vừa |
| 23 | Cá nhân & cài đặt | **Chưa có** (không có file, không có route). Đăng xuất đang nằm ở `team_screen.dart` và `team_settings_sheet.dart` | Cả màn: hồ sơ cầu thủ (Sửa), thống kê cá nhân (trận, bàn, kiến tạo, MVP), đội của tôi, hoạt động (Kèo của tôi, Lịch sử đặt sân, Quỹ của tôi, Danh hiệu), bật/tắt thông báo, khu vực mặc định, Đăng xuất (đã nằm trong M5) | Nặng |
| 24 | Danh sách cảm xúc | **Chưa có** (không có file, không có route) | Cả màn: tab Tất cả + theo loại cảm xúc, danh sách người, "Xem đội". Phụ thuộc cảm xúc ở màn 1 và 14 (M5) | Nặng |
| D | Desktop · Bảng tin | **Chưa có**: app chưa có bố cục theo chiều rộng (chỉ `compare_requests_screen.dart` và `add_fund_tx_screen.dart` có dùng đo kích thước) | Cả layout 3 cột: thanh trên (Sân Chung, tab), cột đội (thống kê, lịch, quỹ, vinh danh), luồng bảng tin, cột "Sân trống tối nay" và "Vua phá lưới". Cần PO chốt có làm bản web/desktop không (PLAN nói app di động) | Nặng |

## Mục theo chủ đề xuyên suốt

| Mục | Chỗ lệch | Mức |
|---|---|---|
| Toast | Đã có toast dùng chung (`core/widgets/app_toast.dart`). Bản vẽ không vẽ toast nên cần anh Duy chốt kiểu hiển thị | Nhẹ |
| Font | App dùng Inter (Google Fonts, trừ iOS dùng chữ hệ thống). Bản vẽ dùng `-apple-system, SF Pro Text, Inter`. Khớp, cần so letter-spacing −0,2 và tiêu đề 34/−0,8 trên máy (theme đặt −0,9) | Nhẹ |
| Màu và token | `core/theme/tokens.dart` khớp bảng màu bản vẽ (#0066cc, #f5f5f7, #1d1d1f, #6e6e73, #248a3d, #d70015). Chưa rà lẻ từng chỗ có hard-code màu trong widget | Nhẹ |
| Trạng thái | Nhiều màn đã có trống/lỗi/thử lại (bản đồ, thông báo, bảng tin). Cần rà riêng trạng thái mất mạng, loading và disabled cho từng màn | Vừa |
| Vùng bấm 44×44 và tương phản AA | Chưa kiểm tra | Vừa |

## Đề xuất thứ tự sửa

1. **Luồng cọc đặt sân (màn 15, 16)** cùng Backend: đây là luồng tiền, quy tắc "chỉ đổi trạng thái khi server xác nhận". Gồm dịch vụ thêm và chia tiền với đội đối.
2. **Sửa nhanh các mục Vừa của M0–M4** (không phụ thuộc backend mới): bộ lọc chip bản đồ (3), loại kèo và dòng tính tiền khi đăng (2), nút "Ứng tuyển" và thẻ Kết quả trong feed (1), hàng khoảng cách và chip lọc (11), chữ quyền phó đội (19), nút "Chia sẻ" (16).
3. **Bình luận và cảm xúc (màn 1, 14, 24)**: cần Backend làm API bình luận và cảm xúc trước. Sau đó làm thanh cảm xúc, danh sách bình luận và màn danh sách cảm xúc.
4. **Kèo của tôi và lịch đăng (màn 10, và phần Hẹn lịch của màn 2)**: cần API lịch lặp.
5. **Chat giữa hai đội (màn 21)**, rồi nối nút "Nhắn tin" ở màn 9, 13, 22.
6. **Trang cá nhân & cài đặt (màn 23)**, chuyển nút Đăng xuất về đây.
7. **Ảnh/video (màn 1, 2, 4, 20)**: cần Backend làm tải lên S3. Làm sau cùng trong M5.
8. **Thẻ nhận xét ở màn 17, 22**: làm cùng một đợt với trường dữ liệu mới.
9. **Desktop (màn D)**: chỉ làm nếu anh Duy xác nhận có bản web/desktop.
10. **Rà chi tiết trên máy (màu, khoảng cách, cỡ chữ, trạng thái, vùng bấm, tương phản)**: làm đợt riêng sau khi chụp ảnh tham chiếu từng màn và so song song.

## Việc chưa làm trong lần rà này

- Chưa chụp ảnh iframe từng màn vào `docs/design/screens/`.
- Chưa mở app trên máy để so thực tế. Các mục ghi "cần xác minh" hoặc "chưa thấy" nghĩa là chưa tìm thấy trong chữ và widget của code, chưa chắc là thiếu thật.
- Chưa đối chiếu với dữ liệu thật từ API (ví dụ ảnh sân, tiện ích, đánh giá sao có trong API hay không).
