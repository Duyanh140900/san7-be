# Sân 7 · Backend

## Dữ liệu OSM và demo

Nguồn sân bóng mở là OpenStreetMap, được nhập qua Overpass API theo giấy phép
ODbL. Màn giới thiệu dữ liệu sân phải hiển thị credit: **© OpenStreetMap
contributors**.

Chạy trên Docker local (không chạy seed demo ở production):

```bash
# Trong thư mục gốc repo
docker compose up -d postgres

# Trong backend/; OSM được cache tại prisma/seed-data/osm/ sau lần tải đầu
npm run build
DATABASE_URL='postgresql://san7:...@localhost:5432/san7?schema=public' npm run import:osm
NODE_ENV=development DATABASE_URL='postgresql://san7:...@localhost:5432/san7?schema=public' npm run seed:demo

# Chỉ xoá dữ liệu demo có email @demo.san7.local và team [DEMO]
NODE_ENV=development DATABASE_URL='postgresql://san7:...@localhost:5432/san7?schema=public' npm run delete:demo
```

Importer chỉ lấy `leisure=pitch` + `sport=soccer` hoặc `leisure=sports_centre`
+ `sport=soccer` tại Hà Nội và TP. Hồ Chí Minh. Khoá `osm_id` đảm bảo chạy lại
không nhân đôi. Vì OSM thường không công bố bảng giá, các khung giá tạo sẵn là
ước lượng để test và được đánh dấu `price_estimated=true`.

NestJS 12 (ESM) + Prisma 7 (PostgreSQL/PostGIS). Xem hướng dẫn chạy ở `../CLAUDE.md` và kế hoạch ở `../docs/PLAN.md`.

```bash
npm install
npm run start:dev      # API ở http://localhost:3000/v1, tài liệu ở /docs
npm test               # test service
npm run openapi        # xuất ../docs/openapi.json
npm run prisma:migrate # tạo migration mới (cần Postgres đang chạy)
```
