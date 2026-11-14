# Sân 7 · Backend

NestJS 12 (ESM) + Prisma 7 (PostgreSQL/PostGIS). Xem hướng dẫn chạy ở `../CLAUDE.md` và kế hoạch ở `../docs/PLAN.md`.

```bash
npm install
npm run start:dev      # API ở http://localhost:3000/v1, tài liệu ở /docs
npm test               # test service
npm run openapi        # xuất ../docs/openapi.json
npm run prisma:migrate # tạo migration mới (cần Postgres đang chạy)
```
