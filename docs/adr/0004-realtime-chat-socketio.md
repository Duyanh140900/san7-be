# ADR 0004: Tin nhắn hai đội dùng Socket.IO

Ngày: 2026-11-16 — Trạng thái: Accepted

API hiện đã dùng Socket.IO tại `/v1/socket`, có JWT khi kết nối và room người dùng/đội. Màn chat hai đội sẽ dùng Socket.IO thay vì SSE để app có kênh hai chiều cho gửi, xác nhận và sự kiện tin mới mà không mở thêm kết nối HTTP dài.

Gateway phải kiểm tra thành viên `active` của một trong hai đội trước khi join room hội thoại; service cũng kiểm tra lại trước khi đọc hoặc ghi. Socket room chỉ là tối ưu realtime, không phải cơ chế phân quyền duy nhất.
