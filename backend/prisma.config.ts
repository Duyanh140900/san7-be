import { config } from 'dotenv';
import { defineConfig } from 'prisma/config';

// Khi chạy ngoài Docker: đọc .env ở gốc repo. Trong Docker biến môi trường có sẵn.
config({ path: '../.env', quiet: true });

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: process.env.DATABASE_URL ?? '' },
});
