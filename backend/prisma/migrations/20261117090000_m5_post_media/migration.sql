-- Ảnh của kèo lưu theo thứ tự hiển thị. Giá trị mặc định giữ tương thích với kèo cũ.
ALTER TABLE "posts"
ADD COLUMN "media" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
